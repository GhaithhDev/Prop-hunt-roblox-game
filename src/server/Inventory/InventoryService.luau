local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local NumberFormat = require(ReplicatedStorage.Shared.Packages.NumberFormat)
local TrailsConfig = require(ReplicatedStorage.Shared.Configs.TrailsConfig)
local AurasConfig = require(ReplicatedStorage.Shared.Configs.AurasConfig)
local MonetizationConfig = require(ReplicatedStorage.Shared.Configs.MonetizationConfig)
local DataManager = require(ServerScriptService.Server.Data.Manager)
local MonetizationService = require(ServerScriptService.Server.Monetization.MonetizationService)
local PressXpService = require(ServerScriptService.Server.PressXp.PressXpService)


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
		Net:RemoteEvent("Notify"):FireClient(player, "error", `You need {NumberFormat.Format(item.WinsCost)} Wins to buy {item.Name}!`)
		return
	end

	DataManager.Add(player, "Wins", -item.WinsCost)
	PressXpService.RecheckEquippedOption(player)
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

local function applyTrailSpeed(player: Player)
	DataManager.YieldUntilLoadedOrReleased(player)
	if not player then return end
	local character = player.Character
	local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	local equippedTrail = DataManager.Get(player, "EquippedTrail") or ""

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = TrailsConfig.GetWalkSpeedForEquipped(equippedTrail)
	end
end

-- Exposed so Data/init.lua can re-apply once the profile finishes loading,
-- in case the character spawned first (see applyEquippedEffects' own guard).
function InventoryService.ApplyEquippedEffects(player: Player)
	applyTrailSpeed(player)
end

-- Clicking Equip on an already-equipped item unequips it instead - same
-- remote handles both, toggled off the currently-equipped id.
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

	local equippedKey = getEquippedKey(category)
	local isCurrentlyEquipped = DataManager.Get(player, equippedKey) == itemId

	if isCurrentlyEquipped then
		DataManager.Set(player, equippedKey, "")
		applyTrailSpeed(player)
		Net:RemoteEvent("Notify"):FireClient(player, "success", `Unequipped {item.Name}!`)
	else
		DataManager.Set(player, equippedKey, itemId)
		applyTrailSpeed(player)
		Net:RemoteEvent("Notify"):FireClient(player, "success", `Equipped {item.Name}!`)
	end
end


function InventoryService.Start()
	Net:Handle("GetInventoryStatus", getStatus)
	Net:Handle("BuyWithWins", onBuyWithWins)
	Net:Connect("RequestRobuxPurchase", onRequestRobuxPurchase)
	Net:Handle("EquipItem", onEquipItem)

	
end

return InventoryService
