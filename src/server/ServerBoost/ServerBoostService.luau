--[[
	ServerBoostService

	One server-wide, escalating, timed XP multiplier - not per-player data,
	so its state (level/expiresAt) lives as plain module-level variables here,
	not DataManager. Buying tier N (2x, 4x, 6x, 8x, 10x - DevProducts.ServerBoost
	is a 5-entry array, index N = that tier's product) raises the level to at
	least N and always restarts a fresh 15-minute window, whatever tier was
	bought. Synced to clients via workspace attributes (the "Server" scope
	ActiveBoostsConfig/ActiveBoostsController already support) rather than
	PlayerData, since every player sees the same value.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local MonetizationConfig = require(ReplicatedStorage.Shared.Configs.MonetizationConfig)
local MonetizationService = require(ServerScriptService.Server.Monetization.MonetizationService)

local MAX_LEVEL = 5
local DURATION = 15 * 60 -- seconds, restarts fresh on every purchase
local SYNC_INTERVAL = 1

local ServerBoostService = {}

local level = 0
local expiresAt = 0

local lastSyncedRemaining: number? = nil

function ServerBoostService.GetMultiplier(): number
	return (os.time() < expiresAt) and level * 2 or 1
end

local function onServerBoostPurchased(newLevel: number)
	level = math.max(level, newLevel)
	expiresAt = os.time() + DURATION
end

local function onRequestServerBoost(player: Player)
	local nextLevel = level + 1
	if nextLevel > MAX_LEVEL then
		Net:RemoteEvent("Notify"):FireClient(player, "error", "Max server boost already active!")
		return
	end

	local serverBoostProducts = MonetizationConfig.DevProducts.ServerBoost
	local productId = serverBoostProducts and serverBoostProducts[nextLevel]
	if not productId or productId == 0 then
		warn(`ServerBoostService: DevProducts.ServerBoost has no valid ProductId for tier {nextLevel} - replace it in MonetizationConfig before shipping`)
		Net:RemoteEvent("Notify"):FireClient(player, "error", "That boost isn't available yet!")
		return
	end

	MonetizationService.PromptPurchaseById(player, productId)
end

function ServerBoostService.Start()
	local serverBoostProducts = MonetizationConfig.DevProducts.ServerBoost
	if serverBoostProducts then
		for tierLevel, productId in serverBoostProducts do
			if productId ~= 0 then
				MonetizationService.RegisterConsumable(productId, function(player: Player)
					onServerBoostPurchased(tierLevel)
					Net:RemoteEvent("Notify"):FireClient(player, "success", `Server boost now x{tierLevel * 2}!`)
				end)
			end
		end
	end

	Net:Connect("RequestServerBoost", onRequestServerBoost)

	task.spawn(function()
		while true do
			task.wait(SYNC_INTERVAL)

			local remaining = math.max(0, expiresAt - os.time())
			if remaining <= 0 and level ~= 0 then
				level = 0
			end

			if lastSyncedRemaining ~= remaining then
				lastSyncedRemaining = remaining
				Workspace:SetAttribute("ServerBoostRemainingSeconds", remaining)
				Workspace:SetAttribute("ServerBoostMultiplier", remaining > 0 and level * 2 or 1)
				Workspace:SetAttribute("ServerBoostNextTierMultiplier", level < MAX_LEVEL and (level + 1) * 2 or nil)
			end
		end
	end)
end

return ServerBoostService
