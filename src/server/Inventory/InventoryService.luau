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

local function applyEquippedEffects(player: Player)
	local character = player.Character
	local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	if DataManager.Get(player, "EquippedTrail") == nil then
		-- Profile hasn't finished loading yet (this character spawned before
		-- StartSessionAsync resolved) - skip instead of falling back to "no
		-- trail". The next equip/unequip or respawn will call this again once
		-- the profile is loaded, so this avoids permanently stranding
		-- WalkSpeed at the no-trail default for the rest of the session.
		return
	end

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

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = TrailsConfig.GetWalkSpeedForEquipped(equippedTrail)
	end

	local equippedAura = DataManager.Get(player, "EquippedAura") or ""
	if equippedAura ~= "" then
		local template = AURA_ASSETS:FindFirstChild(equippedAura)
		if template then
			local clone = template:Clone()
			clone.Name = AURA_PART_NAME

			-- Size/position the emitter part to the character's full bounding
			-- box so the Box-shaped, LockedToPart particle emission (see
			-- ReplicatedStorage.Shared.Assets.Auras) fills the whole body
			-- instead of a single point at the HumanoidRootPart.
			local boundingCFrame, boundingSize = character:GetBoundingBox()
			clone.CFrame = boundingCFrame
			clone.Size = boundingSize
			clone.Parent = humanoidRootPart

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = humanoidRootPart
			weld.Part1 = clone
			weld.Parent = clone
		end
	end
end

-- Exposed so Data/init.lua can re-apply once the profile finishes loading,
-- in case the character spawned first (see applyEquippedEffects' own guard).
function InventoryService.ApplyEquippedEffects(player: Player)
	applyEquippedEffects(player)
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
		applyEquippedEffects(player)
		Net:RemoteEvent("Notify"):FireClient(player, "success", `Unequipped {item.Name}!`)
	else
		DataManager.Set(player, equippedKey, itemId)
		applyEquippedEffects(player)
		Net:RemoteEvent("Notify"):FireClient(player, "success", `Equipped {item.Name}!`)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	character:WaitForChild("HumanoidRootPart", 5)
	applyEquippedEffects(player)
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
