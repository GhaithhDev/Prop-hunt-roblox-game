--[[
	SpeedPassService

	Purchasing/ownership for the permanent SpeedPass tiers is fully handled
	by the generic ShopService (RequestGamePassPurchase/GetShopStatus already
	loop over any MonetizationConfig.GamePasses category). This service only
	provides the multiplier for XpPerPress, plus a periodic sync of that
	multiplier to PlayerData.SpeedPassMultiplier so XpPerPress's client-side
	prediction stays eventually consistent after a purchase - GamePass grants
	flow through ProcessReceipt's fully generic path with no per-category
	callback to hook, so polling is the only way to notice a change (same
	reasoning ServerBoostService's own sync loop already relies on).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SpeedPassConfig = require(ReplicatedStorage.Shared.Configs.SpeedPassConfig)
local DataManager = require(ServerScriptService.Server.Data.Manager)
local MonetizationService = require(ServerScriptService.Server.Monetization.MonetizationService)

local SYNC_INTERVAL = 3

local SpeedPassService = {}

local lastSyncedMultiplier: { [Player]: number } = {}

function SpeedPassService.GetMultiplierForPlayer(player: Player): number
	local owned = {}
	for _, tier in SpeedPassConfig.Tiers do
		owned[tier.Id] = MonetizationService.OwnsPass(player, "SpeedPass", tier.Id)
	end
	return SpeedPassConfig.GetMultiplierForOwned(owned)
end

function SpeedPassService.Start()
	Players.PlayerRemoving:Connect(function(player)
		lastSyncedMultiplier[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(SYNC_INTERVAL)

			for _, player in Players:GetPlayers() do
				local multiplier = SpeedPassService.GetMultiplierForPlayer(player)
				if lastSyncedMultiplier[player] ~= multiplier then
					lastSyncedMultiplier[player] = multiplier
					DataManager.SyncToClient(player, "SpeedPassMultiplier", multiplier)
				end
			end
		end
	end)
end

return SpeedPassService
