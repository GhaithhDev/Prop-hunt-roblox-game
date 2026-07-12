local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local MonetizationConfig = require(ReplicatedStorage.Shared.Configs.MonetizationConfig)
local DataManager = require(ServerScriptService.Server.Data.Manager)

local OWNED_CATEGORY = "OwnedPasses"
local PROCESSED_PURCHASES_KEY = "ProcessedPurchaseIds"
local SAVE_CONFIRM_TIMEOUT = 10 -- seconds to wait for a durable save before asking Roblox to retry instead

local MonetizationService = {}

-- Dynamically registered by feature services (e.g. TeleportService) at their own
local consumableHandlers: { [number]: (Player, any) -> () } = {}

-- Ownership keys are namespaced by category ("Treadmills_Gold", "Trails_Ember")
-- so the same bare pass name can be reused across categories without colliding
-- in the flat OwnedPasses store.
local function buildOwnedKey(category: string, passId: string): string
	return category .. "_" .. passId
end

function MonetizationService.OwnsPass(player: Player, category: string, passId: string): boolean
	return DataManager.Owns(player, OWNED_CATEGORY, buildOwnedKey(category, passId))
end

-- Plain (non-save-confirmed) grant for non-Robux paths (e.g. a Wins purchase)
-- where the durability guarantees grantPassAndConfirmSave exists for aren't
-- needed - there's no real-money charge to protect against a lost grant.
function MonetizationService.GrantPass(player: Player, category: string, passId: string)
	DataManager.SetOwned(player, OWNED_CATEGORY, buildOwnedKey(category, passId), true)
end

-- Generic prompt with no MonetizationConfig lookup - usable for both GamePasses
-- and Consumables, since callers already resolve their own ProductId directly.
function MonetizationService.PromptPurchaseById(player: Player, productId: number)
	Net:RemoteEvent("ShowPurchaseLoading"):FireClient(player, productId)
	MarketplaceService:PromptProductPurchase(player, productId)
end

-- Registers a fulfillment callback for a raw Developer Product ID, called once
-- per purchase (deduped by PurchaseId in processReceipt below). Safe to call
-- from any service's Start(), regardless of ordering relative to this file's
-- own Start() - ProcessReceipt is only ever invoked by Roblox well after every
-- service has booted.
function MonetizationService.RegisterConsumable(productId: number, onPurchased: (Player, any) -> ())
	if consumableHandlers[productId] then
		warn(`MonetizationService: RegisterConsumable called twice for ProductId {productId} - overwriting previous handler`)
	end
	consumableHandlers[productId] = onPurchased
end

-- Grants the pass in-memory (idempotent), then blocks (bounded) until the
-- grant is confirmed durably saved. Returns true only if confirmed saved.
local function grantPassAndConfirmSave(player: Player, category: string, passId: string): boolean
	local profile = DataManager.Profiles[player]
	if not profile then return false end

	DataManager.SetOwned(player, OWNED_CATEGORY, buildOwnedKey(category, passId), true)

	if not profile:IsActive() then
		return false -- session already ending; can't confirm from here
	end

	local saved = false
	local connection = profile.OnAfterSave:Connect(function()
		saved = true
	end)

	profile:Save()

	local waited = 0
	while not saved and waited < SAVE_CONFIRM_TIMEOUT and profile:IsActive() do
		task.wait(0.25)
		waited += 0.25
	end
	connection:Disconnect()

	return saved
end

-- Scoped to only the GamePass categories (not DevProducts) so a DevProduct ID
-- can never be mistaken for a permanent Pass grant.
local function findGamePassByProductId(productId: number): (string?, string?)
	for categoryName, category in MonetizationConfig.GamePasses do
		for passId, id in category do
			if id == productId then return categoryName, passId end
		end
	end
	return nil, nil
end

local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- Player isn't in this server (left, or a stale offline receipt).
		-- Retry later - e.g. when they rejoin - rather than losing the purchase.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if not DataManager.Profiles[player] then
		-- Present, but ProfileStore session hasn't finished loading yet. Retry shortly.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local category, passId = findGamePassByProductId(receiptInfo.ProductId)
	if passId then
		if MonetizationService.OwnsPass(player, category, passId) then
			-- Already durably owned (redelivered receipt); nothing new to grant,
			-- but must still acknowledge it or Roblox retries forever.
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		local confirmed = grantPassAndConfirmSave(player, category, passId)
		if confirmed then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		-- Granted in memory but couldn't confirm the save landed. Ask Roblox to
		-- retry; the retry is a safe no-op grant on this server (already owned),
		-- or a correct fresh grant on a fresh server if this one actually died.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local consumableHandler = consumableHandlers[receiptInfo.ProductId]
	if consumableHandler then
		if DataManager.HasInList(player, PROCESSED_PURCHASES_KEY, receiptInfo.PurchaseId) then
			-- Already fulfilled this exact purchase (redelivered receipt); idempotent no-op.
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		-- No profile:Save()+OnAfterSave confirm here (unlike Pass grants above).
		-- The first consumer (stage teleport) is a one-time positional action:
		-- if the server crashes between AddToList and the next autosave, the
		-- dedup record is lost but the purchase itself isn't - a redelivered
		-- receipt would just cause a harmless duplicate teleport, not a lost-
		-- value bug. A FUTURE consumable granting cumulative/valuable effects
		-- (e.g. a currency pack) must NOT copy this - it needs the heavier
		-- confirmed-save treatment grantPassAndConfirmSave uses above, or a
		-- crash-retry becomes a real dupe-currency exploit.
		DataManager.AddToList(player, PROCESSED_PURCHASES_KEY, receiptInfo.PurchaseId)
		consumableHandler(player, receiptInfo)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	warn(`MonetizationService: ProcessReceipt got unrecognized ProductId {receiptInfo.ProductId} `
		.. `(PurchaseId {receiptInfo.PurchaseId}, Player {receiptInfo.PlayerId}) - no matching GamePass config entry or registered consumable handler`)
	return Enum.ProductPurchaseDecision.PurchaseGranted -- nothing sensible to grant; stop the retry loop
end

function MonetizationService.Start()
	for _, category in MonetizationConfig.GamePasses do
		for passId, productId in category do
			if productId == 0 then
				warn(`MonetizationService: "{passId}" has a placeholder ProductId (0) - replace it in MonetizationConfig before shipping`)
			end
		end
	end
	-- DevProducts entries can be a bare ProductId (e.g. RebirthSkip) or a nested
	-- table of ProductIds (e.g. SkipToStage, keyed per stage) - walk both shapes.
	for name, value in MonetizationConfig.DevProducts do
		if type(value) == "table" then
			for subKey, productId in value do
				if productId == 0 then
					warn(`MonetizationService: "{name}.{subKey}" has a placeholder ProductId (0) - replace it in MonetizationConfig before shipping`)
				end
			end
		elseif value == 0 then
			warn(`MonetizationService: "{name}" has a placeholder ProductId (0) - replace it in MonetizationConfig before shipping`)
		end
	end

	MarketplaceService.ProcessReceipt = processReceipt
end

return MonetizationService
