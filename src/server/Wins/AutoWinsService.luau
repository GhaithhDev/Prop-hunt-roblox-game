--//Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataManager = nil

--//Configs
local RemoteConfig = require(ReplicatedStorage.Shared.Configs.RemoteConfig)
local StageGates = require(ReplicatedStorage.Shared.Configs.StageGates)

--// Pacakges
local Net = require(ReplicatedStorage.Shared.Packages.Net)
local Trove = require(ReplicatedStorage.Shared.Packages.Trove)

--//Constants
local REACHED_DISTANCE = 4 -- studs; how close counts as "arrived" at the midpoint
local COOLDOWN_TIME = 1 -- seconds; how much will player wait before starting to run to win another time

--//Cache
local AutoWinsPlayers = {} --[[ player.UserId -> {WinPosition: Vector3, MidPosition: Vector3, ReachedMid: boolean, Ready: boolean, Trove: Trove, OnCoolDown = false, } ]]
local AutoWinsService = {}

-- Central teardown: removes the player's entry and cleans up any connections
-- tied to their auto-wins session (CharacterAdded / Died watchers). Safe to
-- call even if the player has no active session.
local function StopAutoWins(userId: number)
	local data = AutoWinsPlayers[userId]
	if not data then
		return
	end

	if data.Trove then
		data.Trove:Destroy()
	end

	AutoWinsPlayers[userId] = nil
end

local function MovePlayersToTargetPart()
	for userId, data in pairs(AutoWinsPlayers) do
		if not data.Ready then
			continue
		end
		if data.OnCoolDown and data.CoolDownSecondsLeft > 0 then
			data.CoolDownSecondsLeft -= 1
			if data.CoolDownSecondsLeft <= 0 then
				local player = Players:GetPlayerByUserId(userId)
				if player then
					SetAutoWins(Players:GetPlayerByUserId(userId), true)
				end
			end
		end
		if data.OnCoolDown then
			continue
		end

		local player = Players:GetPlayerByUserId(userId)
		if not player then
			StopAutoWins(userId)
			continue
		end

		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local rootPart = humanoid and humanoid.RootPart

		if not humanoid or not rootPart or humanoid.Health <= 0 then
			StopAutoWins(userId)
			continue
		end

		if not data.ReachedMid then
			humanoid:MoveTo(data.MidPosition)
			if (rootPart.Position - data.MidPosition).Magnitude <= REACHED_DISTANCE then
				data.ReachedMid = true
			end
		else
			if
				(rootPart.Position - data.WinPosition).Magnitude <= REACHED_DISTANCE
				or rootPart.Position.Z > workspace.Functional.AutoWinsStart.Position.Z
			then
				print("Player " .. player.Name .. " reached win position, starting cooldown.")
				data.ReachedMid = false
				data.CoolDownSecondsLeft = COOLDOWN_TIME
				data.OnCoolDown = true
				continue
			end
			humanoid:MoveTo(data.WinPosition)
		end
	end
end

local function TeleportPlayerToStart(character: Model)
	character:PivotTo(workspace.Functional.AutoWinsStart.CFrame)
end

local function GetBestUnlockedStage(player: Player): string
	DataManager.YieldUntilLoadedOrReleased(player)
	local playerData = DataManager.GetData(player)
	if not playerData then
		return "1"
	end

	local bestUnlockedStage = "1"
	for stageName, requiredLevel in pairs(StageGates.LevelRequriements) do
		if tonumber(stageName) > tonumber(bestUnlockedStage) and playerData.Level >= requiredLevel then
			bestUnlockedStage = stageName
		end
	end

	return bestUnlockedStage
end

local function GetPlayerTargetPositions(player: Player)
	local bestUnlockedStage = GetBestUnlockedStage(player)
	local stageFolder = workspace.Decorations.Stages:FindFirstChild("Stage" .. bestUnlockedStage)
	if not stageFolder then
		warn("Stage folder not found " .. player.Name .. " at stage " .. bestUnlockedStage)
		return nil, nil
	end
	local winPosition = stageFolder.Wins.FreeWins:FindFirstChildWhichIsA("Part").Position
	local x2WinsPosition = stageFolder.Wins["2xWins"]:FindFirstChildWhichIsA("Part").Position
	local centerPosition = (winPosition + x2WinsPosition) / 2
	return winPosition, centerPosition
end

-- Starts watching the player's current character for death so the session
-- gets torn down immediately rather than waiting on the next poll tick.
local function WatchForDeath(player: Player, data)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	data.Trove:Add(humanoid.Died:Connect(function()
		StopAutoWins(player.UserId)
	end))
end

local function PrepareCharacter(player: Player)
	local data = AutoWinsPlayers[player.UserId]
	if not data then
		return
	end

	if player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
		TeleportPlayerToStart(player.Character)
		data.Ready = true
		WatchForDeath(player, data)
	else
		data.Trove:Add(player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid")
			if humanoid.Health > 0 then
				TeleportPlayerToStart(character)
				data.Ready = true
				WatchForDeath(player, data)
			end
		end))
	end
end

function SetAutoWins(player: Player, startAutoWins: boolean)
    print("setting auto win for player " .. player.Name .. " to " .. tostring(startAutoWins))
	if typeof(startAutoWins) ~= "boolean" then
		player:Kick("Exploiter: called SetAutoWins with invalid arguments")

		warn(player.Name .. " Exploiter: called SetAutoWins with invalid arguments")
		return
	end

	if not startAutoWins then
		StopAutoWins(player.UserId)
		return
	end

	-- Clear out any previous session (and its connections) before starting fresh.
	StopAutoWins(player.UserId)

	local winPosition, midPosition = GetPlayerTargetPositions(player)
	if not winPosition or not midPosition then
		return
	end

	AutoWinsPlayers[player.UserId] = {
		WinPosition = winPosition,
		MidPosition = midPosition,
		ReachedMid = false,
		Ready = false,
		OnCoolDown = false,
		CoolDownSecondsLeft = COOLDOWN_TIME,
		Trove = Trove.new(),
	}

	PrepareCharacter(player)
end

function AutoWinsService.Start()
	DataManager = require(ServerScriptService.Server.Data.Manager)
	Net:Connect(RemoteConfig.Wins.SetAutoWins.Name, SetAutoWins)

	Players.PlayerRemoving:Connect(function(player)
		StopAutoWins(player.UserId)
	end)

	task.spawn(function()
		while task.wait(1) do
			MovePlayersToTargetPart()
		end
	end)

	local function PlayerAddedTesting(player)
		local trove = Trove.new()
		trove:Add(player.CharacterAdded:Connect(function(character)
			SetAutoWins(player, true)
			trove:Destroy() -- Clean up the connection after it's used once
		end))
	end
	for _, player in ipairs(Players:GetPlayers()) do
		PlayerAddedTesting(player)
	end
	Players.PlayerAdded:Connect(PlayerAddedTesting)
end
return AutoWinsService
