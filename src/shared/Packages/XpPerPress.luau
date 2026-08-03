local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local XpPerPressConfig = require(ReplicatedStorage.Shared.Configs.XpPerPressConfig)
local RebirthConfig = require(ReplicatedStorage.Shared.Configs.RebirthConfig)
local TrailsConfig = require(ReplicatedStorage.Shared.Configs.TrailsConfig)
local AurasConfig = require(ReplicatedStorage.Shared.Configs.AurasConfig)

local XpPerPress = {}

-- Placeholder multipliers for systems that don't exist yet. Each should be
-- swapped for the real calculation once its system is built, without
-- touching GetAmountForPlayer/GetAmountForLocalPlayer or their callers.
local function getRebirthMultiplier(stats: { [string]: any }): number
	return RebirthConfig.GetMultiplierForRebirths(stats.Rebirths or 0)
end

local function getAurasMultiplier(stats: { [string]: any }): number
	return AurasConfig.GetMultiplierForEquipped(stats.EquippedAura or "")
end

local function getTrailsMultiplier(stats: { [string]: any }): number
	return TrailsConfig.GetMultiplierForEquipped(stats.EquippedTrail or "")
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

-- Server: reads XpBoostService's live state. Client: reads the replicated
-- PlayerData.XpBoostRemainingSeconds value XpBoostService syncs every second
-- while active (display/prediction only — the server path below is what
-- actually grants XP).
local function getXpBoostMultiplier(stats: { [string]: any }): number
	if RunService:IsServer() then
		local player = stats.Player
		if not player then
			return 1
		end
		-- Required inline (not at module top-level) to avoid a circular require:
		-- XpBoostService requires XpPerPress at its own top level.
		local XpBoostService = require(game:GetService("ServerScriptService").Server.XpBoost.XpBoostService)
		return XpBoostService.HasActiveBoost(player) and 2 or 1
	end
	return (stats.XpBoostRemainingSeconds or 0) > 0 and 2 or 1
end

-- Server: reads ShrinkPassService's live state (recomputed fresh from owned
-- passes every call - always accurate). Client: reads the replicated
-- PlayerData.ShrinkPassMultiplier value ShrinkPassService periodically syncs
-- (display/prediction only, and only eventually consistent after a purchase -
-- see ShrinkPassService's own comment for why polling is needed there).
local function getShrinkPassMultiplier(stats: { [string]: any }): number
	if RunService:IsServer() then
		local player = stats.Player
		if not player then
			return 1
		end
		-- Required inline (not at module top-level) to avoid a circular require:
		-- ShrinkPassService requires XpPerPress at its own top level.
		local ShrinkPassService = require(game:GetService("ServerScriptService").Server.ShrinkPass.ShrinkPassService)
		return ShrinkPassService.GetMultiplierForPlayer(player)
	end
	return stats.ShrinkPassMultiplier or 1
end

-- Server-global, not per-player - reads ServerBoostService's live state
-- directly on the server, and the replicated workspace attribute it syncs
-- on the client. No stats.Player/PlayerData lookup needed either way, since
-- every player sees the same value.
local function getServerBoostMultiplier(): number
	if RunService:IsServer() then
		-- Required inline (not at module top-level) to avoid a circular require:
		-- ServerBoostService requires XpPerPress at its own top level.
		local ServerBoostService = require(game:GetService("ServerScriptService").Server.ServerBoost.ServerBoostService)
		return ServerBoostService.GetMultiplier()
	end
	return Workspace:GetAttribute("ServerBoostMultiplier") or 1
end

-- Server-global, not per-player - admin-set, cross-server multiplier. Same
-- shape as getServerBoostMultiplier: server reads AdminService's live state,
-- client reads the replicated workspace attribute.
local function getAdminXpMultiplier(): number
	if RunService:IsServer() then
		-- Required inline for consistency with the other live-service lookups
		-- above (no actual circular-require risk here, AdminService doesn't
		-- require XpPerPress).
		local AdminService = require(game:GetService("ServerScriptService").Server.Admin.AdminService)
		return AdminService.GetXpMultiplier()
	end
	return Workspace:GetAttribute("AdminXpMultiplier") or 1
end

local function calculateAmount(stats: { [string]: any }): number
	local baseAmount = XpPerPressConfig.GetStepAmount(stats.EquippedPressOption or XpPerPressConfig.DefaultOption, stats.World)
	local multiplier = getRebirthMultiplier(stats) * getAurasMultiplier(stats) * getTrailsMultiplier(stats) * getTreadmillMultiplier(stats) * getXpBoostMultiplier(stats) * getShrinkPassMultiplier(stats) * getServerBoostMultiplier() * getAdminXpMultiplier()
	return math.floor(baseAmount * multiplier)
end

-- Server-authoritative: reads live profile data. Only callable from the server.
function XpPerPress.GetAmountForPlayer(player: Player): number
	assert(RunService:IsServer(), "XpPerPress.GetAmountForPlayer can only be called from the server")

	local ServerScriptService = game:GetService("ServerScriptService")
	local DataManager = require(ServerScriptService.Server.Data.Manager)

	return calculateAmount({
		EquippedPressOption = DataManager.Get(player, "EquippedPressOption"),
		World = DataManager.Get(player, "World"),
		Rebirths = DataManager.Get(player, "Rebirths"),
		EquippedTrail = DataManager.Get(player, "EquippedTrail"),
		EquippedAura = DataManager.Get(player, "EquippedAura"),
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
	local worldValue = playerData and playerData:FindFirstChild("World")
	local treadmillMultiplierValue = playerData and playerData:FindFirstChild("TreadmillMultiplier")
	local rebirthsValue = playerData and playerData:FindFirstChild("Rebirths")
	local equippedTrailValue = playerData and playerData:FindFirstChild("EquippedTrail")
	local equippedAuraValue = playerData and playerData:FindFirstChild("EquippedAura")
	local xpBoostRemainingValue = playerData and playerData:FindFirstChild("XpBoostRemainingSeconds")
	local shrinkPassMultiplierValue = playerData and playerData:FindFirstChild("ShrinkPassMultiplier")

	return calculateAmount({
		EquippedPressOption = equippedValue and equippedValue.Value,
		World = worldValue and worldValue.Value,
		TreadmillMultiplier = treadmillMultiplierValue and treadmillMultiplierValue.Value,
		XpBoostRemainingSeconds = xpBoostRemainingValue and xpBoostRemainingValue.Value,
		Rebirths = rebirthsValue and rebirthsValue.Value,
		EquippedTrail = equippedTrailValue and equippedTrailValue.Value,
		EquippedAura = equippedAuraValue and equippedAuraValue.Value,
		ShrinkPassMultiplier = shrinkPassMultiplierValue and shrinkPassMultiplierValue.Value,
	})
end

return XpPerPress
