--[[
	XpBoostService

	Sells a temporary 2x XP-per-press boost in tiers defined by
	src/shared/Configs/XpBoostConfig.luau (Shop's "x2 Speed" section).
	Tracked as a wall-clock expiry timestamp (DataManager "XpBoostExpiresAt"),
	not a session timer, so it survives disconnects - purchases stack
	additively on top of whatever time is already left, never discarding paid
	time. XpPerPress.luau reads XpBoostService.HasActiveBoost server-side and
	the replicated XpBoostRemainingSeconds client-side to apply the 2x
	multiplier.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local MonetizationConfig = require(ReplicatedStorage.Shared.Configs.MonetizationConfig)
local XpBoostConfig = require(ReplicatedStorage.Shared.Configs.XpBoostConfig)
local DataManager = require(ServerScriptService.Server.Data.Manager)
local MonetizationService = require(ServerScriptService.Server.Monetization.MonetizationService)

local SYNC_INTERVAL = 1 -- seconds between remaining-time syncs to clients

local XpBoostService = {}

local lastSyncedRemaining: { [Player]: number } = {}

-- DevProducts.XpBoost is a plain array, positionally matched to
-- XpBoostConfig (index 1 <-> XpBoostConfig[1], etc.) rather than keyed by
-- duration - so a lookup either direction goes through XpBoostConfig's order.
local function findConfigIndexForDuration(durationMinutes: number): number?
	for index, item in XpBoostConfig do
		if item.DurationMinutes == durationMinutes then
			return index
		end
	end
	return nil
end

function XpBoostService.HasActiveBoost(player: Player): boolean
	local expiresAt = DataManager.Get(player, "XpBoostExpiresAt") or 0
	return os.time() < expiresAt
end

local function onXpBoostPurchased(player: Player, durationMinutes: number)
	local currentExpiresAt = DataManager.Get(player, "XpBoostExpiresAt") or 0
	local newExpiresAt = math.max(currentExpiresAt, os.time()) + durationMinutes * 60
	DataManager.Set(player, "XpBoostExpiresAt", newExpiresAt)
	Net:RemoteEvent("Notify"):FireClient(player, "success", `2x XP boost +{durationMinutes} minutes!`)
end

local function onRequestXpBoost(player: Player, durationMinutes: number)
	durationMinutes = tonumber(durationMinutes) :: number

	local configIndex = findConfigIndexForDuration(durationMinutes)
	local xpBoostProducts = MonetizationConfig.DevProducts.XpBoost
	local productId = configIndex and xpBoostProducts and xpBoostProducts[configIndex]
	if not productId or productId == 0 then
		warn(`XpBoostService: DevProducts.XpBoost has no valid ProductId for {durationMinutes} minutes (index {tostring(configIndex)}) - replace it in MonetizationConfig before shipping`)
		Net:RemoteEvent("Notify"):FireClient(player, "error", "That boost isn't available yet!")
		return
	end

	MonetizationService.PromptPurchaseById(player, productId)
end

function XpBoostService.Start()
	local xpBoostProducts = MonetizationConfig.DevProducts.XpBoost
	if xpBoostProducts then
		for index, productId in xpBoostProducts do
			local item = XpBoostConfig[index]
			if item and productId ~= 0 then
				local durationMinutes = item.DurationMinutes
				MonetizationService.RegisterConsumable(productId, function(player: Player)
					onXpBoostPurchased(player, durationMinutes)
				end)
			end
		end
	end

	Net:Connect("RequestXpBoost", onRequestXpBoost)

	task.spawn(function()
		while true do
			task.wait(SYNC_INTERVAL)
			for _, player in Players:GetPlayers() do
				local expiresAt = DataManager.Get(player, "XpBoostExpiresAt") or 0
				local remaining = math.max(0, math.floor(expiresAt - os.time()))
				if lastSyncedRemaining[player] ~= remaining then
					lastSyncedRemaining[player] = remaining
					DataManager.SyncToClient(player, "XpBoostRemainingSeconds", remaining)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastSyncedRemaining[player] = nil
	end)
end

return XpBoostService
