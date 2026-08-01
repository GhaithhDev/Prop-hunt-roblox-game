--[[
	GlobalLeaderboardService

	Populates the three world signboards under Workspace.Functional.GlobalLeaderboards
	directly (they're Workspace instances, not per-player StarterGui, so normal
	replication shows the result to everyone - no remotes/client controller needed).

	Cross-server ranking uses DataStoreService:GetOrderedDataStore, one store per
	stat. Writes are rate-limit-safe: a periodic sync loop pushes each connected
	player's current stat only when it changed since the last push (bounded by
	player count / interval, not by how often the stat actually changes), and a
	separate, longer-interval loop re-fetches top N and repopulates the boards.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")

local LeaderboardConfig = require(ReplicatedStorage.Shared.Configs.LeaderboardConfig)
local NumberFormat = require(ReplicatedStorage.Shared.Packages.NumberFormat)
local DataManager = require(ServerScriptService.Server.Data.Manager)

local GlobalLeaderboardService = {}

-- Formats a raw seconds count as "XdYh"/"XhYm"/"Xm" for the TimePlayed board,
-- since NumberFormat.Format's K/M/B suffixes read as a score, not a duration.
local function formatPlayTime(totalSeconds: number): string
	local minutes = totalSeconds // 60
	local hours = minutes // 60
	local days = hours // 24

	if days > 0 then
		return `{days}d {hours % 24}h`
	elseif hours > 0 then
		return `{hours}h {minutes % 60}m`
	end
	return `{minutes}m`
end

local boards = {
	{
		Store = DataStoreService:GetOrderedDataStore("GlobalLevelLeaderboard"),
		BoardPart = workspace.Functional.GlobalLeaderboards.Level.LevelLeaderboard,
		DataKey = "Level",
	},
	{
		Store = DataStoreService:GetOrderedDataStore("GlobalWinsLeaderboard"),
		BoardPart = workspace.Functional.GlobalLeaderboards.Wins.WinsLeaderboard,
		DataKey = "Wins",
	},
	{
		Store = DataStoreService:GetOrderedDataStore("GlobalTimePlayedLeaderboard"),
		BoardPart = workspace.Functional.GlobalLeaderboards.TimePlayed.GuiPart,
		DataKey = "TimePlayed",
		Format = formatPlayTime,
	},
}

local lastSyncedValue: { [Player]: { [string]: number } } = {}
local nameCache: { [number]: string } = {}

local function getPlayerName(userId: number): string
	local connectedPlayer = Players:GetPlayerByUserId(userId)
	if connectedPlayer then
		return connectedPlayer.Name
	end

	local cached = nameCache[userId]
	if cached then
		return cached
	end

	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local resolved = ok and name or `Player{userId}`
	nameCache[userId] = resolved
	return resolved
end

local function syncPlayerStats()
	for _, player in Players:GetPlayers() do
		lastSyncedValue[player] = lastSyncedValue[player] or {}

		for _, board in boards do
			local synced = lastSyncedValue[player]
			local value = DataManager.Get(player, board.DataKey)
			if value and synced[board.DataKey] ~= value then
				local ok, err = pcall(function()
					board.Store:SetAsync(tostring(player.UserId), value)
				end)
				if ok then
					-- player may have disconnected while SetAsync was yielding,
					-- clearing lastSyncedValue[player] via PlayerRemoving
					if lastSyncedValue[player] then
						lastSyncedValue[player][board.DataKey] = value
					end
				else
					warn(`GlobalLeaderboardService: failed to sync {board.DataKey} for {player.Name}:`, err)
				end
			end
		end
	end
end

local function clearRows(scrollingFrame: ScrollingFrame, template: Frame)
	for _, child in scrollingFrame:GetChildren() do
		if child:IsA("Frame") and child ~= template then
			child:Destroy()
		end
	end
end

local function refreshBoard(board)
	local ok, pages = pcall(function()
		return board.Store:GetSortedAsync(false, LeaderboardConfig.TopCount)
	end)
	if not ok then
		warn(`GlobalLeaderboardService: failed to fetch {board.DataKey} leaderboard:`, pages)
		return
	end

	local entries = pages:GetCurrentPage()

	local scrollingFrame = board.BoardPart.SurfaceGui.ScrollingFrame
	local template = scrollingFrame.UIGridLayout.Template
	clearRows(scrollingFrame, template)

	for rank, entry in entries do
		local userId = tonumber(entry.key)
		if not userId then continue end

		local row = template:Clone()
		row.Name = entry.key
		row.Visible = true

		local rankLabel = row:FindFirstChild("TextLabel")
		local nameLabel = row:FindFirstChild("PlayerName")
		local valueLabel = row:FindFirstChild("AmountofCash")

		if rankLabel then rankLabel.Text = tostring(rank) end
		if nameLabel then nameLabel.Text = getPlayerName(userId) end
		if valueLabel then
			local format = board.Format or NumberFormat.Format
			valueLabel.Text = format(entry.value)
		end

		row.Parent = scrollingFrame
	end
end

function GlobalLeaderboardService.Start()
	syncPlayerStats()
	for _, board in boards do
		refreshBoard(board)
	end

	Players.PlayerRemoving:Connect(function(player)
		lastSyncedValue[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(LeaderboardConfig.StatSyncInterval)
			syncPlayerStats()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(LeaderboardConfig.DisplayRefreshInterval)
			for _, board in boards do
				refreshBoard(board)
			end
		end
	end)

	-- No other system tracks play time, so accrue it here: one second per
	-- connected player per tick, which syncPlayerStats then pushes upstream
	-- like any other stat once it changes.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				DataManager.Add(player, "TimePlayed", 1)
			end
		end
	end)
end

return GlobalLeaderboardService
