local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local TrailsConfig = require(ReplicatedStorage.Shared.Configs.TrailsConfig)
local AurasConfig = require(ReplicatedStorage.Shared.Configs.AurasConfig)
local MonetizationConfig = require(ReplicatedStorage.Shared.Configs.MonetizationConfig)
local DataManager = require(ServerScriptService.Server.Data.Manager)
local MonetizationService = require(ServerScriptService.Server.Monetization.MonetizationService)

local TRAIL_ASSETS = ReplicatedStorage.Shared.Assets.Trails
local AURA_ASSETS = ReplicatedStorage.Shared.Assets.Auras

-- Every Trail template's Folder contains children with these exact fixed
-- names (only Color/etc differ per trail) - lets cleanup find and remove
-- whichever trail is currently equipped without needing to track which one.
local TRAIL_PART_NAMES = { "Attachment0", "Attachment1", "TrailEffect" }
local AURA_PART_NAME = "AuraEffect"

local InventoryService = {}

local function getConfig(category: string)
	if category == "Trail" then
		return TrailsConfig
	elseif category == "Aura" then
		return AurasConfig
	end
	return nil
end

local function getEquippedKey(category: string): string
	return category == "Trail" and "EquippedTrail" or "EquippedAura"
end

-- Maps the Net-remote "Trail"/"Aura" category strings to the plural
-- MonetizationConfig.GamePasses key names used for ownership tracking.
local function getGamePassCategory(category: string): string
	return category == "Trail" and "Trails" or "Auras"
end

local function getStatus(player: Player)
	local function buildList(config, gamePassCategory)
		local list = {}
		for id, item in config.Items do
			table.insert(list, {
				Id = id,
				Name = item.Name,
				WinsCost = item.WinsCost,
				Multiplier = item.Multiplier,
				Owned = MonetizationService.OwnsPass(player, gamePassCategory, id),
			})
		end
		return list
	end

	return {
		Trails = buildList(TrailsConfig, "Trails"),
		Auras = buildList(AurasConfig, "Auras"),
		EquippedTrail = DataManager.Get(player, "EquippedTrail") or "",
		EquippedAura = DataManager.Get(player, "EquippedAura") or "",
	}
end

local function onBuyWithWins(player: Player, category: string, itemId: string)
	local config = getConfig(category)
	local item = config and config.Items[itemId]
	if not item then
		Net:RemoteEvent("Notify"):FireClient(player, "error", "That item doesn't exist.")
		return
	end

	local gamePassCategory = getGamePassCategory(category)
	if MonetizationService.OwnsPass(player, gamePassCategory, itemId) then
		Net:RemoteEvent("Notify"):FireClient(player, "error", `You already own {item.Name}!`)
		return
	end

	local wins = DataManager.Get(player, "Wins") or 0
	if wins < item.WinsCost then
		Net:RemoteEvent("Notify"):FireClient(player, "error", `You need {item.WinsCost} Wins to buy {item.Name}!`)
		return
	end

	DataManager.Add(player, "Wins", -item.WinsCost)
	MonetizationService.GrantPass(player, gamePassCategory, itemId)
	Net:RemoteEvent("Notify"):FireClient(player, "success", `Purchased {item.Name}!`)
end

local function onRequestRobuxPurchase(player: Player, category: string, itemId: string)
	local config = getConfig(category)
	local item = config and config.Items[itemId]
	if not item then
		Net:RemoteEvent("Notify"):FireClient(player, "error", "That item doesn't exist.")
		return
	end

	local gamePassCategory = getGamePassCategory(category)
	local productId = MonetizationConfig.GamePasses[gamePassCategory][itemId]
	if not productId or productId == 0 then
		Net:RemoteEvent("Notify"):FireClient(player, "error", "That item isn't purchasable with Robux yet.")
		return
	end

	if MonetizationService.OwnsPass(player, gamePassCategory, itemId) then
		Net:RemoteEvent("Notify"):FireClient(player, "error", `You already own {item.Name}!`)
		return
	end

	MonetizationService.PromptPurchaseById(player, productId)
end

local function applyEquippedVisuals(player: Player)
	local character = player.Character
	local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	for _, name in TRAIL_PART_NAMES do
		local existing = humanoidRootPart:FindFirstChild(name)
		if existing then existing:Destroy() end
	end
	local existingAura = humanoidRootPart:FindFirstChild(AURA_PART_NAME)
	if existingAura then existingAura:Destroy() end

	local equippedTrail = DataManager.Get(player, "EquippedTrail") or ""
	if equippedTrail ~= "" then
		local template = TRAIL_ASSETS:FindFirstChild(equippedTrail)
		if template then
			local clone = template:Clone()
			for _, part in clone:GetChildren() do
				part.Parent = humanoidRootPart
			end
			clone:Destroy()
		end
	end

	local equippedAura = DataManager.Get(player, "EquippedAura") or ""
	if equippedAura ~= "" then
		local template = AURA_ASSETS:FindFirstChild(equippedAura)
		if template then
			local clone = template:Clone()
			clone.Name = AURA_PART_NAME
			clone.Parent = humanoidRootPart
		end
	end
end

local function onEquipItem(player: Player, category: string, itemId: string)
	local config = getConfig(category)
	local item = config and config.Items[itemId]
	if not item then
		Net:RemoteEvent("Notify"):FireClient(player, "error", "That item doesn't exist.")
		return
	end

	if not MonetizationService.OwnsPass(player, getGamePassCategory(category), itemId) then
		Net:RemoteEvent("Notify"):FireClient(player, "error", `You don't own {item.Name} yet!`)
		return
	end

	DataManager.Set(player, getEquippedKey(category), itemId)
	applyEquippedVisuals(player)
	Net:RemoteEvent("Notify"):FireClient(player, "success", `Equipped {item.Name}!`)
end

local function onCharacterAdded(player: Player, character: Model)
	character:WaitForChild("HumanoidRootPart", 5)
	applyEquippedVisuals(player)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

function InventoryService.Start()
	Net:Handle("GetInventoryStatus", getStatus)
	Net:Handle("BuyWithWins", onBuyWithWins)
	Net:Connect("RequestRobuxPurchase", onRequestRobuxPurchase)
	Net:Handle("EquipItem", onEquipItem)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
end

return InventoryService
