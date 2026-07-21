--[[
	AdminService

	Whitelist-gated admin actions, applied locally then broadcast to every
	other live server via MessagingService (JobId-guarded so a server never
	re-processes its own broadcast). The two multipliers are server-wide, not
	per-player, so their state lives as plain module-level variables (same
	treatment ServerBoostService already uses for its own timed multiplier),
	synced to Workspace attributes for clients to read.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local MessagingService = game:GetService("MessagingService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local AdminConfig = require(ReplicatedStorage.Shared.Configs.AdminConfig)
local TreadmillService = require(ServerScriptService.Server.Treadmill.TreadmillService)

local TOPIC = "AdminAction"
local SYNC_INTERVAL = 1

local AdminService = {}

local xpMultiplier = 1
local xpExpiresAt = 0
local winsMultiplier = 1
local winsExpiresAt = 0

local lastSyncedXpMultiplier: number? = nil
local lastSyncedWinsMultiplier: number? = nil
local lastSyncedXpRemaining: number? = nil
local lastSyncedWinsRemaining: number? = nil

function AdminService.GetXpMultiplier(): number
	return (os.time() < xpExpiresAt) and xpMultiplier or 1
end

function AdminService.GetWinsMultiplier(): number
	return (os.time() < winsExpiresAt) and winsMultiplier or 1
end

-- Runs identically on every server that processes this action (the
-- originating one, immediately, and every other live server via the
-- MessagingService subscription below) - firing the broadcast Notify here
-- means every player on every server sees it, not just the admin's own server.
local function handleAction(action: string, data: { [string]: any })
	if action == "SetXpMultiplier" then
		xpMultiplier = data.Multiplier
		xpExpiresAt = os.time() + data.Duration
		Net:RemoteEvent("Notify"):FireAllClients("success", `An admin activated a {data.Multiplier}x Shrink boost for {data.Duration} seconds!`)
	elseif action == "SetWinsMultiplier" then
		winsMultiplier = data.Multiplier
		winsExpiresAt = os.time() + data.Duration
		Net:RemoteEvent("Notify"):FireAllClients("success", `An admin activated a {data.Multiplier}x Wins boost for {data.Duration} seconds!`)
	elseif action == "SpawnEventTreadmill" then
		TreadmillService.SpawnEventTreadmill(data.Name, data.Duration)
		Net:RemoteEvent("Notify"):FireAllClients("success", `An admin spawned a {data.Name} event treadmill for {data.Duration} seconds!`)
	elseif action == "Announce" then
		Net:RemoteEvent("AdminAnnouncement"):FireAllClients(data.PlayerName, data.PlayerUserId, data.Message)
	end
end

local function broadcastToOtherServers(action: string, data: { [string]: any })
	local ok, err = pcall(function()
		MessagingService:PublishAsync(TOPIC, {
			Action = action,
			Data = data,
			JobId = game.JobId,
		})
	end)
	if not ok then
		warn("AdminService: failed to publish to MessagingService:", err)
	end
end

local function onAdminAction(player: Player, action: string, arg1: any, arg2: any)
	if AdminConfig.WHITELIST_ACTIVE and not table.find(AdminConfig.Whitelist, player.UserId) then
		warn(`AdminService: {player.Name} ({player.UserId}) tried to fire AdminAction but isn't whitelisted`)
		return
	end

	local data: { [string]: any }
	if action == "SetXpMultiplier" or action == "SetWinsMultiplier" then
		local multiplier = tonumber(arg1)
		local duration = tonumber(arg2)
		if not multiplier or not duration then
			Net:RemoteEvent("Notify"):FireClient(player, "error", "Enter a valid multiplier and duration.")
			return
		end
		data = { Multiplier = multiplier, Duration = duration }
	elseif action == "SpawnEventTreadmill" then
		local name = arg1
		local duration = tonumber(arg2)
		if not name or name == "" or not duration then
			Net:RemoteEvent("Notify"):FireClient(player, "error", "Enter a valid treadmill name and duration.")
			return
		end
		data = { Name = name, Duration = duration }
	elseif action == "Announce" then
		local message = arg1
		if not message or message == "" then
			Net:RemoteEvent("Notify"):FireClient(player, "error", "Enter a message to announce.")
			return
		end
		data = { Message = message, PlayerName = player.Name, PlayerUserId = player.UserId }
	else
		warn(`AdminService: unknown action "{tostring(action)}"`)
		return
	end

	handleAction(action, data)
	broadcastToOtherServers(action, data)
end

function AdminService.Start()
	Net:Connect("AdminAction", onAdminAction)

	local ok, err = pcall(function()
		MessagingService:SubscribeAsync(TOPIC, function(message)
			local data = message.Data
			if data and data.Action and data.JobId ~= game.JobId then
				handleAction(data.Action, data.Data)
			end
		end)
	end)
	if not ok then
		warn("AdminService: failed to subscribe to MessagingService:", err)
	end

	task.spawn(function()
		while true do
			task.wait(SYNC_INTERVAL)

			local currentXpMultiplier = AdminService.GetXpMultiplier()
			if lastSyncedXpMultiplier ~= currentXpMultiplier then
				lastSyncedXpMultiplier = currentXpMultiplier
				Workspace:SetAttribute("AdminXpMultiplier", currentXpMultiplier)
			end

			local currentWinsMultiplier = AdminService.GetWinsMultiplier()
			if lastSyncedWinsMultiplier ~= currentWinsMultiplier then
				lastSyncedWinsMultiplier = currentWinsMultiplier
				Workspace:SetAttribute("AdminWinsMultiplier", currentWinsMultiplier)
			end

			-- Remaining-seconds attributes, for ActiveBoostsConfig's "Server"
			-- scope entries (see ActiveBoostsConfig.luau) - same pattern
			-- ServerBoostService already uses for its own countdown.
			local xpRemaining = math.max(0, xpExpiresAt - os.time())
			if lastSyncedXpRemaining ~= xpRemaining then
				lastSyncedXpRemaining = xpRemaining
				Workspace:SetAttribute("AdminXpRemainingSeconds", xpRemaining)
			end

			local winsRemaining = math.max(0, winsExpiresAt - os.time())
			if lastSyncedWinsRemaining ~= winsRemaining then
				lastSyncedWinsRemaining = winsRemaining
				Workspace:SetAttribute("AdminWinsRemainingSeconds", winsRemaining)
			end
		end
	end)
end

return AdminService
