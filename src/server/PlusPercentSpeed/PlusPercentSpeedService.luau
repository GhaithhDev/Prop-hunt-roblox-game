--[[
	PlusPercentSpeedService

	Sells a one-time flat "Speed" bonus equal to a configured percentage
	(PlusPercentSpeedConfig) of whatever the player's Speed stat happens to be
	at the moment of purchase - repeatable, not permanent ownership, so this
	registers 3 consumables (MonetizationConfig.DevProducts.PlusPercentSpeed)
	rather than using the GamePasses/OwnsPass pattern.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local MonetizationConfig = require(ReplicatedStorage.Shared.Configs.MonetizationConfig)
local PlusPercentSpeedConfig = require(ReplicatedStorage.Shared.Configs.PlusPercentSpeedConfig)
local NumberFormat = require(ReplicatedStorage.Shared.Packages.NumberFormat)
local DataManager = require(ServerScriptService.Server.Data.Manager)
local MonetizationService = require(ServerScriptService.Server.Monetization.MonetizationService)
local LevelService = require(ServerScriptService.Server.Level.LevelService)

local PlusPercentSpeedService = {}

local function onOptionPurchased(player: Player, optionName: string)
	local percent = PlusPercentSpeedConfig[optionName]
	if not percent then
		warn(`PlusPercentSpeedService: no PlusPercentSpeedConfig entry for "{optionName}"`)
		return
	end

	local currentSpeed = DataManager.Get(player, "Speed") or 0
	local bonus = math.floor(currentSpeed * percent)
	LevelService.GrantXp(player, bonus)
	Net:RemoteEvent("Notify"):FireClient(player, "success", `+{NumberFormat.Format(bonus)} Speed!`)
end

local function onRequestPlusPercentSpeed(player: Player, optionName: string)
	local productId = MonetizationConfig.DevProducts.PlusPercentSpeed and MonetizationConfig.DevProducts.PlusPercentSpeed[optionName]
	if not productId or productId == 0 then
		Net:RemoteEvent("Notify"):FireClient(player, "error", "That isn't purchasable yet.")
		return
	end

	MonetizationService.PromptPurchaseById(player, productId)
end

function PlusPercentSpeedService.Start()
	local products = MonetizationConfig.DevProducts.PlusPercentSpeed
	if products then
		for optionName, productId in products do
			if productId ~= 0 then
				MonetizationService.RegisterConsumable(productId, function(player: Player)
					onOptionPurchased(player, optionName)
				end)
			end
		end
	end

	Net:Connect("RequestPlusPercentSpeed", onRequestPlusPercentSpeed)
end

return PlusPercentSpeedService
