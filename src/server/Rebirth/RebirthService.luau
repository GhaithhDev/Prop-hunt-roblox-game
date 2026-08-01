local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local RebirthConfig = require(ReplicatedStorage.Shared.Configs.RebirthConfig)
local MonetizationConfig = require(ReplicatedStorage.Shared.Configs.MonetizationConfig)
local RemoteConfig = require(ReplicatedStorage.Shared.Configs.RemoteConfig)
local DataManager = require(ServerScriptService.Server.Data.Manager)
local LevelService = require(ServerScriptService.Server.Level.LevelService)
local MonetizationService = require(ServerScriptService.Server.Monetization.MonetizationService)

local RebirthService = {}

local pendingSkipIntent: { [Player]: number } = {}

local function getStatus(player: Player)
	local currentRebirths = DataManager.Get(player, "Rebirths") or 0
	local currentLevel = DataManager.Get(player, "Level") or 1
	local nextTier = RebirthConfig.GetTier(currentRebirths + 1)

	return {
		Rebirths = currentRebirths,
		CurrentMultiplier = RebirthConfig.GetMultiplierForRebirths(currentRebirths),
		Level = currentLevel,
		NextRequiredLevel = nextTier and nextTier.RequiredLevel or 0,
		NextMultiplier = nextTier and nextTier.Multiplier or 1,
		MeetsRequirement = nextTier ~= nil and currentLevel >= nextTier.RequiredLevel,
	}
end

-- Shared by both the normal (level-gated) rebirth and the paid skip - the
-- grant itself is identical either way, only the gating check differs.
local function grantRebirth(player: Player, rebirthNumber: number, tier: RebirthConfig.Tier)
	LevelService.ResetProgress(player)
	DataManager.Set(player, "Rebirths", rebirthNumber)
	Net:RemoteEvent("Notify"):FireClient(player, "success", `Rebirth #{rebirthNumber}! Now earning {tier.Multiplier}x XP!`)
	Net:RemoteEvent(RemoteConfig.UIEffects.FlashWhiteScreen.Name):FireClient(player)

	if player.Character then
		task.defer(function()
			local oldCharacter = player.Character
			player.Character = nil 
			oldCharacter:Destroy()
			player:LoadCharacterAsync()
		end)
	end
end

local function performRebirth(player: Player)
	local currentRebirths = DataManager.Get(player, "Rebirths") or 0
	local nextRebirthNumber = currentRebirths + 1
	local tier = RebirthConfig.GetTier(nextRebirthNumber)

	if not tier then
		Net:RemoteEvent("Notify"):FireClient(player, "error", "Rebirths are not configured yet!")
		return
	end

	local currentLevel = DataManager.Get(player, "Level") or 1
	if currentLevel < tier.RequiredLevel then
		Net:RemoteEvent("Notify"):FireClient(player, "error", `Reach level {tier.RequiredLevel} to rebirth!`)
		return
	end

	grantRebirth(player, nextRebirthNumber, tier)
end

local function onRequestSkipRebirth(player: Player)
	local skipProductId = MonetizationConfig.DevProducts.RebirthSkip
	if skipProductId == 0 then
		warn("RebirthService: DevProducts.RebirthSkip has a placeholder ProductId (0) - replace it in MonetizationConfig before shipping")
		Net:RemoteEvent("Notify"):FireClient(player, "error", "Skip Rebirth isn't available yet!")
		return
	end

	local currentRebirths = DataManager.Get(player, "Rebirths") or 0
	local nextRebirthNumber = currentRebirths + 1
	local tier = RebirthConfig.GetTier(nextRebirthNumber)

	if not tier then
		Net:RemoteEvent("Notify"):FireClient(player, "error", "Rebirths are not configured yet!")
		return
	end

	pendingSkipIntent[player] = nextRebirthNumber
	MonetizationService.PromptPurchaseById(player, skipProductId)
end

local function onSkipPurchased(player: Player, receiptInfo)
	local rebirthNumber = pendingSkipIntent[player]
	pendingSkipIntent[player] = nil

	if not rebirthNumber then
		warn(`RebirthService: skip purchase confirmed for {player.Name} but no pendingSkipIntent - skipping grant`)
		return
	end

	-- The player may have already rebirthed normally (or skipped again) while
	-- this purchase was in flight - re-derive the tier fresh rather than
	-- trusting the number captured at prompt-time.
	local currentRebirths = DataManager.Get(player, "Rebirths") or 0
	local actualNextNumber = currentRebirths + 1
	local tier = RebirthConfig.GetTier(actualNextNumber)
	if not tier then return end

	grantRebirth(player, actualNextNumber, tier)
end

function RebirthService.Start()
	local skipProductId = MonetizationConfig.DevProducts.RebirthSkip
	if skipProductId ~= 0 then
		MonetizationService.RegisterConsumable(skipProductId, onSkipPurchased)
	end

	Net:Handle("GetRebirthStatus", getStatus)
	Net:Handle("PerformRebirth", performRebirth)
	Net:Connect("RequestSkipRebirth", onRequestSkipRebirth)
end

return RebirthService
