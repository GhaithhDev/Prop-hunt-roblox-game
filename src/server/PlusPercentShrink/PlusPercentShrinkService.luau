--[[
	PlusPercentShrinkService

	Sells a one-time flat "Shrink" bonus equal to a configured percentage
	(PlusPercentShrinkConfig) of whatever the player's Shrink stat happens to be
	at the moment of purchase - repeatable, not permanent ownership, so this
	registers 3 consumables (MonetizationConfig.DevProducts.PlusPercentShrink)
	rather than using the GamePasses/OwnsPass pattern.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local MonetizationConfig = require(ReplicatedStorage.Shared.Configs.MonetizationConfig)
local PlusPercentShrinkConfig = require(ReplicatedStorage.Shared.Configs.PlusPercentShrinkConfig)
local NumberFormat = require(ReplicatedStorage.Shared.Packages.NumberFormat)
local DataManager = require(ServerScriptService.Server.Data.Manager)
local MonetizationService = require(ServerScriptService.Server.Monetization.MonetizationService)
local LevelService = require(ServerScriptService.Server.Level.LevelService)

local PlusPercentShrinkService = {}

local function onOptionPurchased(player: Player, optionName: string)
	local percent = PlusPercentShrinkConfig[optionName]
	if not percent then
		warn(`PlusPercentShrinkService: no PlusPercentShrinkConfig entry for "{optionName}"`)
		return
	end

	local currentShrink = DataManager.Get(player, "Shrink") or 0
	local bonus = math.floor(currentShrink * percent)
	LevelService.GrantXp(player, bonus)
	Net:RemoteEvent("Notify"):FireClient(player, "success", `+{NumberFormat.Format(bonus)} Shrink!`)
end

local function onRequestPlusPercentShrink(player: Player, optionName: string)
	local productId = MonetizationConfig.DevProducts.PlusPercentShrink and MonetizationConfig.DevProducts.PlusPercentShrink[optionName]
	if not productId or productId == 0 then
		Net:RemoteEvent("Notify"):FireClient(player, "error", "That isn't purchasable yet.")
		return
	end

	MonetizationService.PromptPurchaseById(player, productId)
end

function PlusPercentShrinkService.Start()
	local products = MonetizationConfig.DevProducts.PlusPercentShrink
	if products then
		for optionName, productId in products do
			if productId ~= 0 then
				MonetizationService.RegisterConsumable(productId, function(player: Player)
					onOptionPurchased(player, optionName)
				end)
			end
		end
	end

	Net:Connect("RequestPlusPercentShrink", onRequestPlusPercentShrink)
end

return PlusPercentShrinkService
