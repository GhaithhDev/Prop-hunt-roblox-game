local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local XpPerPressConfig = require(ReplicatedStorage.Shared.Configs.XpPerPressConfig)

local XpPerPress = {}

-- Placeholder multipliers for systems that don't exist yet. Each should be
-- swapped for the real calculation once its system is built, without
-- touching GetAmountForPlayer/GetAmountForLocalPlayer or their callers.
local function getRebirthMultiplier(stats: { [string]: any }): number
	return 1
end

local function getAurasMultiplier(stats: { [string]: any }): number
	return 1
end

local function getTrailsMultiplier(stats: { [string]: any }): number
	return 1
end

-- Server: reads TreadmillService's live state. Client: reads the replicated
-- PlayerData.TreadmillMultiplier value TreadmillService syncs on change (display/
-- prediction only — the server path below is what actually grants XP).
local function getTreadmillMultiplier(stats: { [string]: any }): number
	if RunService:IsServer() then
		local player = stats.Player
		if not player then
			return 1
		end
		-- Required inline (not at module top-level) to avoid a circular require:
		-- TreadmillService requires XpPerPress at its own top level.
		local TreadmillService = require(game:GetService("ServerScriptService").Server.Treadmill.TreadmillService)
		return TreadmillService.GetMultiplierForPlayer(player)
	end
	return stats.TreadmillMultiplier or 1
end

local function calculateAmount(stats: { [string]: any }): number
	local baseAmount = XpPerPressConfig.GetStepAmount(stats.EquippedPressOption or XpPerPressConfig.DefaultOption)
	local multiplier = getRebirthMultiplier(stats) * getAurasMultiplier(stats) * getTrailsMultiplier(stats) * getTreadmillMultiplier(stats)
	return math.floor(baseAmount * multiplier)
end

-- Server-authoritative: reads live profile data. Only callable from the server.
function XpPerPress.GetAmountForPlayer(player: Player): number
	assert(RunService:IsServer(), "XpPerPress.GetAmountForPlayer can only be called from the server")

	local ServerScriptService = game:GetService("ServerScriptService")
	local DataManager = require(ServerScriptService.Server.Data.Manager)

	return calculateAmount({
		EquippedPressOption = DataManager.Get(player, "EquippedPressOption"),
		Player = player,
	})
end

-- Client-side: reads the local player's replicated PlayerData. For display/prediction
-- only — the server's GetAmountForPlayer is what actually determines XP granted.
function XpPerPress.GetAmountForLocalPlayer(): number
	assert(RunService:IsClient(), "XpPerPress.GetAmountForLocalPlayer can only be called from the client")

	local player = Players.LocalPlayer
	local playerData = player and player:FindFirstChild("PlayerData")
	local equippedValue = playerData and playerData:FindFirstChild("EquippedPressOption")
	local treadmillMultiplierValue = playerData and playerData:FindFirstChild("TreadmillMultiplier")

	return calculateAmount({
		EquippedPressOption = equippedValue and equippedValue.Value,
		TreadmillMultiplier = treadmillMultiplierValue and treadmillMultiplierValue.Value,
	})
end

return XpPerPress
