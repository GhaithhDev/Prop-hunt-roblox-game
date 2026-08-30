--[[
	RoundService

	The Prop Hunt round/game-loop state machine: waits for >=2 players, splits
	them into Hiders/Seekers Teams, swaps a random map from ServerStorage.Maps
	into Workspace, runs a hide-phase head start then an active hunt phase, and
	loops back to waiting once a round ends.

	Win conditions are tracked off Humanoid.Died (the one signal guaranteed to
	fire exactly once per life for every death cause) rather than
	GunService.Eliminated (which only fires for gun-caused deaths and would miss
	e.g. fall damage) - see removeFromRound below. Tool grants are one-shot
	pushes to the snapshotted round roster at each phase transition, never
	reactive to CharacterAdded, so a mid-round respawn can't accidentally get
	re-armed.

	Players who join mid-round sit on the Lobby Team (set unconditionally by
	PlayerAdded) until the next WaitingForPlayers cycle picks them up, since
	round-start team assignment only ever pulls players currently on Lobby.
]]

--//Services
local FriendService = game:GetService("FriendService")
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--//Configs
local RoundConfig = require(ReplicatedStorage.Shared.Configs.RoundConfig)
local RemoteConfig = require(ReplicatedStorage.Shared.Configs.RemoteConfig)

--//Packages
local Net = require(ReplicatedStorage.Shared.Packages.Net)

--//Server
local ToggleMorphService = require(script.Parent.Parent.Morph.ToggleMorphService)

local RoundService = {}

local DEFAULT_WALK_SPEED = 16
local DEFAULT_JUMP_POWER = 50
local WIN_CHECK_INTERVAL = 0.5
local SPAWN_RANDOM_RADIUS = 10
local LOBBY_RANDOM_RADIUS = 6

--=============================================================================
-- Teams
--=============================================================================

local LobbyTeam: Team
local HidersTeam: Team
local SeekersTeam: Team

local function ensureTeam(name: string, color: BrickColor): Team
	local team = Teams:FindFirstChild(name)
	if team and team:IsA("Team") then
		return team
	end

	team = Instance.new("Team")
	team.Name = name
	team.TeamColor = color
	team.AutoAssignable = false
	team.Parent = Teams
	return team
end

--=============================================================================
-- Map / Lobby containers
--=============================================================================

local lobbyModel: Model? = nil
local currentMapContainer: Folder

local function ensureLobbyInWorkspace()
	local existing = Workspace:FindFirstChild(RoundConfig.LobbyModelName)
	if existing and existing:IsA("Model") then
		lobbyModel = existing
		return
	end

	local stored = ServerStorage:FindFirstChild("LobbyModelFolder"):FindFirstChild(RoundConfig.LobbyModelName)
	if stored and stored:IsA("Model") then
		stored.Parent = Workspace
		lobbyModel = stored
	end
end

local function ensureCurrentMapContainer(): Folder
	local existing = Workspace:FindFirstChild("CurrentMap")
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = "CurrentMap"
	folder.Parent = Workspace
	return folder
end

--=============================================================================
-- Remotes
--=============================================================================

local statusRemote: RemoteEvent

local currentPhase = "WaitingForPlayers"
local currentEndsAt: number? = nil
local currentExtra: any = nil

local function pushStatus(phase: string, endsAt: number?, extra: any?)
	currentPhase = phase
	currentEndsAt = endsAt
	currentExtra = extra
	statusRemote:FireAllClients(phase, endsAt, extra)
end

local function announce(text: string)
	Net:RemoteEvent("Notify"):FireAllClients("info", text)
end

--=============================================================================
-- Round roster / state
--=============================================================================

local roundHiders: { [Player]: boolean } = {}
local roundSeekers: { [Player]: boolean } = {}
local hidersRemaining = 0
local seekersRemaining = 0

--=============================================================================
-- Spawning helpers
--=============================================================================

local function randomOffset(radius: number): Vector3
	local angle = math.random() * math.pi * 2
	local distance = math.random() * radius
	return Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

-- Reads marker Parts/Attachments from container[folderName] if present, else
-- falls back to fallbackPivot + a random offset - the primary path until a
-- map has been given real spawn folders.
local function getSpawnPositions(container: Instance?, folderName: string, fallbackPivot: CFrame, count: number): { Vector3 }
	local markers = {}
	local folder = container and container:FindFirstChild(folderName)
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(markers, child.Position)
			elseif child:IsA("Attachment") then
				table.insert(markers, child.WorldPosition)
			end
		end
	end

	local positions = {}
	for i = 1, count do
		if #markers > 0 then
			table.insert(positions, markers[((i - 1) % #markers) + 1])
		else
			table.insert(positions, fallbackPivot.Position + randomOffset(SPAWN_RANDOM_RADIUS))
		end
	end
	return positions
end

local function teleportTo(player: Player, position: Vector3)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not rootPart then
		return
	end
	character:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)))
end

local function getLobbyPivot(): CFrame
	if lobbyModel then
		local spawn = lobbyModel:FindFirstChild(RoundConfig.LobbySpawnName)
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame
		elseif spawn and spawn:IsA("Attachment") then
			return spawn.WorldCFrame
		end
		return lobbyModel:GetPivot()
	end
	return CFrame.new()
end

local function teleportToLobby(player: Player)
	teleportTo(player, getLobbyPivot().Position + randomOffset(LOBBY_RANDOM_RADIUS))
end

--=============================================================================
-- Tools / freeze
--=============================================================================

local function giveTool(player: Player, toolName: string)
	local toolsFolder = ServerStorage:FindFirstChild(RoundConfig.RoundToolsFolderName)
	local template = toolsFolder and toolsFolder:FindFirstChild(toolName)
	if not template then
		warn(`RoundService: missing round tool "{toolName}" in ServerStorage.{RoundConfig.RoundToolsFolderName}`)
		return
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		template:Clone().Parent = backpack
	end
end

local function stripTools(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		backpack:ClearAllChildren()
	end

	local character = player.Character
	if character then
		for _, tool in character:GetChildren() do
			if tool:IsA("Tool") then
				tool:Destroy()
			end
		end
	end
end

local function setFrozen(player: Player, frozen: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.WalkSpeed = frozen and 0 or DEFAULT_WALK_SPEED
	humanoid.JumpPower = frozen and 0 or DEFAULT_JUMP_POWER
end

local function healToFull(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = humanoid.MaxHealth
	end
end

--=============================================================================
-- Elimination / round membership
--=============================================================================

-- Setting Team = X already auto-clears Neutral (Roblox links the two - see
-- onPlayerAdded's comment for the reverse case), so this alone is sufficient.
local function resetToLobby(player: Player)
	player.Team = LobbyTeam
end

-- Called from Humanoid.Died (any death cause) and PlayerRemoving - must be
-- idempotent, since a player who dies and immediately disconnects would
-- otherwise be double-counted.
local function removeFromRound(player: Player)
	local wasHider = roundHiders[player]
	local wasSeeker = roundSeekers[player]
	if not wasHider and not wasSeeker then
		return
	end

	if wasHider then
		roundHiders[player] = nil
		hidersRemaining -= 1
		ToggleMorphService.Unmorph(player)
	else
		roundSeekers[player] = nil
		seekersRemaining -= 1
	end

	player:SetAttribute("Eliminated", true)
	resetToLobby(player)
	stripTools(player)
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Once(function()
			removeFromRound(player)
		end)
	end

	-- Round-start/teleport-to-map is done directly by runRound - this only
	-- matters for a fresh join or a post-elimination respawn, both of which
	-- already have Team == Lobby by the time the new character loads.
	if player.Team == LobbyTeam then
		task.defer(teleportToLobby, player)
	end
end

local function onPlayerAdded(player: Player)
	-- Assigning Team already auto-clears Neutral - setting Neutral = true
	-- afterward would silently reset Team back to nil (confirmed live: Roblox
	-- treats these two properties as mutually exclusive, whichever is set
	-- last wins), so Team alone is sufficient here.
	player.Team = LobbyTeam
	player:SetAttribute("Eliminated", false)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

--=============================================================================
-- Round loop
--=============================================================================

local function getLobbyPlayers(): { Player }
	local list = {}
	for _, player in Players:GetPlayers() do
		if player.Team == LobbyTeam then
			table.insert(list, player)
		end
	end
	return list
end

local function shuffle(list: { any })
	for i = #list, 2, -1 do
		local j = math.random(i)
		list[i], list[j] = list[j], list[i]
	end
end

local function runRound()
	-- Countdown - ticks once/sec so a leave that drops below MinPlayers is
	-- noticed immediately instead of only after a blind sleep finishes.
	pushStatus("Countdown", Workspace:GetServerTimeNow() + RoundConfig.LobbyCountdownDuration)
	for _ = 1, RoundConfig.LobbyCountdownDuration do
		task.wait(1)
		if #getLobbyPlayers() < RoundConfig.MinPlayers then
			return
		end
	end

	-- Team assignment - no yields between snapshot and Team/Neutral assignment,
	-- so a player joining at this exact instant is either cleanly included or
	-- cleanly excluded, never torn-state.
	local lobbyPlayers = getLobbyPlayers()
	if #lobbyPlayers < RoundConfig.MinPlayers then
		return
	end
	shuffle(lobbyPlayers)

	local hidersCount = math.ceil(#lobbyPlayers / 2)
	roundHiders = {}
	roundSeekers = {}
	local allRoundPlayers = table.clone(lobbyPlayers)

	for index, player in lobbyPlayers do
		-- Assigning Team already sets Neutral = false as a side effect (see
		-- onPlayerAdded's comment), so canPlayerDamageHumanoid's team-gating
		-- is live the instant this runs.
		if index <= hidersCount then
			roundHiders[player] = true
			player.Team = HidersTeam
			player:SetAttribute("MorphCount", 0)
		else
			roundSeekers[player] = true
			player.Team = SeekersTeam
		end
		player:SetAttribute("Eliminated", false)
	end
	hidersRemaining = hidersCount
	seekersRemaining = #lobbyPlayers - hidersCount

	-- Map selection
	currentMapContainer:ClearAllChildren()
	local mapsFolder = ServerStorage:FindFirstChild(RoundConfig.MapsFolderName)
	local mapTemplates = mapsFolder and mapsFolder:GetChildren() or {}
	local mapModel: Model? = nil
	if #mapTemplates > 0 then
		mapModel = (mapTemplates[math.random(#mapTemplates)] :: Model):Clone()
		mapModel.Parent = currentMapContainer
	end

	-- Teleport (yields allowed here - assignment above already finished)
	local mapPivot = mapModel and mapModel:GetPivot() or CFrame.new()
	local hiderSpawns = getSpawnPositions(mapModel, RoundConfig.HiderSpawnsFolderName, mapPivot, hidersCount)
	local seekerSpawns = getSpawnPositions(mapModel, RoundConfig.SeekerSpawnsFolderName, mapPivot, seekersRemaining)

	local hiderIndex, seekerIndex = 0, 0
	for _, player in lobbyPlayers do
		if roundHiders[player] then
			hiderIndex += 1
			teleportTo(player, hiderSpawns[hiderIndex])
		else
			seekerIndex += 1
			teleportTo(player, seekerSpawns[seekerIndex])
		end
	end

	-- HidePhase - Hiders use the proximity-prompt morph flow (MorphPromptController
	-- / ToggleMorphService), Seekers are frozen and do not get guns yet.
	pushStatus("HidePhase", Workspace:GetServerTimeNow() + RoundConfig.HidePhaseDuration)
	for player in roundSeekers do
		setFrozen(player, true)
	end
	task.wait(RoundConfig.HidePhaseDuration)

	-- Anyone who still hasn't morphed gets forced into a random prop so every
	-- Hider is concealed before Seekers are released.
	for player in roundHiders do
		if not player:GetAttribute("IsMorph") then
			ToggleMorphService.ForceRandomMorph(player)
		end
	end

	-- Active - unfreeze Seekers, arm them, start the round timer.
	for player in roundSeekers do
		setFrozen(player, false)
		for _, gunName in RoundConfig.DefaultGuns do
			giveTool(player, gunName)
		end
	end
	pushStatus("Active", Workspace:GetServerTimeNow() + RoundConfig.RoundDuration)

	local timedOut = false
	local timerThread = task.delay(RoundConfig.RoundDuration, function()
		timedOut = true
	end)

	while hidersRemaining > 0 and seekersRemaining > 0 and not timedOut do
		task.wait(WIN_CHECK_INTERVAL)
	end
	task.cancel(timerThread)

	local winner = if hidersRemaining <= 0 then "Seekers" else "Hiders"

	-- Ended
	pushStatus("Ended", nil, { Winner = winner })
	announce(`{winner} win!`)

	for _, player in allRoundPlayers do
		if roundHiders[player] then
			ToggleMorphService.Unmorph(player)
		end
		resetToLobby(player)
		stripTools(player)
		healToFull(player)
		player:SetAttribute("Eliminated", false)
		teleportToLobby(player)
	end
	roundHiders = {}
	roundSeekers = {}

	task.wait(RoundConfig.RoundEndDelay)
	currentMapContainer:ClearAllChildren()
end

local function mainLoop()
	while true do
		pushStatus("WaitingForPlayers")
		while #getLobbyPlayers() < RoundConfig.MinPlayers do
			task.wait(1)
		end
		runRound()
	end
end

--=============================================================================
-- Lifecycle
--=============================================================================

local function InitTeams()
	LobbyTeam = ensureTeam("Lobby", BrickColor.new("Medium stone grey"))
	HidersTeam = ensureTeam("Hiders", BrickColor.new("Bright blue"))
	SeekersTeam = ensureTeam("Seekers", BrickColor.new("Bright red"))
end

function RoundService.Init()
	InitTeams()

	ensureLobbyInWorkspace()
	currentMapContainer = ensureCurrentMapContainer()
end

function RoundService.Start()
	statusRemote = Net:RemoteEvent(RemoteConfig.Round.StatusChanged.Name)

	-- Lets a (re)joining client synchronously fetch the current phase/endsAt/
	-- extra instead of waiting for the next StatusChanged broadcast, which
	-- could be a long time away if they join mid-round.
	Net:Handle(RemoteConfig.Round.RequestCurrentStatus.Name, function(_player)
		return currentPhase, currentEndsAt, currentExtra
	end)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(removeFromRound)

	task.spawn(mainLoop)
end

return RoundService
