--[[
	ShrinkPassService

	Purchasing/ownership for the permanent ShrinkPass tiers is fully handled
	by the generic ShopService (RequestGamePassPurchase/GetShopStatus already
	loop over any MonetizationConfig.GamePasses category). This service only
	provides the multiplier for XpPerPress, plus a periodic sync of that
	multiplier to PlayerData.ShrinkPassMultiplier so XpPerPress's client-side
	prediction stays eventually consistent after a purchase - GamePass grants
	flow through ProcessReceipt's fully generic path with no per-category
	callback to hook, so polling is the only way to notice a change (same
	reasoning ServerBoostService's own sync loop already relies on).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ShrinkPassConfig = require(ReplicatedStorage.Shared.Configs.ShrinkPassConfig)
local DataManager = require(ServerScriptService.Server.Data.Manager)
local MonetizationService = require(ServerScriptService.Server.Monetization.MonetizationService)

local SYNC_INTERVAL = 3

local ShrinkPassService = {}

local lastSyncedMultiplier: { [Player]: number } = {}

function ShrinkPassService.GetMultiplierForPlayer(player: Player): number
	local owned = {}
	for _, tier in ShrinkPassConfig.Tiers do
		owned[tier.Id] = MonetizationService.OwnsPass(player, "ShrinkPass", tier.Id)
	end
	return ShrinkPassConfig.GetMultiplierForOwned(owned)
end

function ShrinkPassService.Start()
	Players.PlayerRemoving:Connect(function(player)
		lastSyncedMultiplier[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(SYNC_INTERVAL)

			for _, player in Players:GetPlayers() do
				local multiplier = ShrinkPassService.GetMultiplierForPlayer(player)
				if lastSyncedMultiplier[player] ~= multiplier then
					lastSyncedMultiplier[player] = multiplier
					DataManager.SyncToClient(player, "ShrinkPassMultiplier", multiplier)
				end
			end
		end
	end)
end

return ShrinkPassService
