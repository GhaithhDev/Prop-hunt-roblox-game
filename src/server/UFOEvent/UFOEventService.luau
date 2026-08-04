local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local UFOEventConfig = require(ReplicatedStorage.Shared.Configs.UFOEventConfig)
local DataManager = require(ServerScriptService.Server.Data.Manager)
local WinsService = require(ServerScriptService.Server.Wins.WinsService)

local UFO_TEMPLATE = ReplicatedStorage.Shared.Assets.EventModels.UFO
local REWARD_VFX_TEMPLATE = ReplicatedStorage.Shared.Assets.VFX.Events.UFO
local EVENT_SKY_TEMPLATE = ReplicatedStorage.Shared.Assets.EventSkies.UFO.Sky

local SYNC_INTERVAL = 1

local BEAM_FLASH_INFO = TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local BEAM_MIN_TRANSPARENCY = 0.55
local BEAM_MAX_TRANSPARENCY = 0.9

local UFOEventService = {}

type UFOEntry = {
	Model: Model,
	Connection: RBXScriptConnection,
	ClaimedRef: { claimed: boolean },
}

-- Keyed by world number (1/2/3) - each world runs its own independent UFO
-- pool/folder within its own UFOEventConfig.Worlds[world] spawn bounds. The
-- event's overall lifecycle (eventActive/expiresAt/sky) stays a single shared
-- timer across all 3 worlds - see StartEvent/StopEvent.
local ufoFolder: { [number]: Folder } = {}
local activeUFOs: { [number]: { UFOEntry } } = {}
-- The future EventManager starts/stops this via StartEvent/StopEvent - guards
-- double-start/stop and stops a just-finished abduction from spawning a
-- replacement UFO after the event's already been told to stop.
local eventActive = false
local expiresAt = 0
-- Detached (Parent = nil, not destroyed) rather than cloned/recreated, so
-- restoring it on StopEvent can't drift from whatever it actually was.
local originalSky: Sky? = nil

local lastAbductionTime: { [Player]: number } = {}
-- Separate from the cooldown timestamp below (which is short - see
-- UFOEventConfig.CooldownSeconds) - this blocks a second UFO from claiming
-- the same player mid-sequence, since the cooldown alone can't since the
-- sequence itself outlasts it.
local abductingPlayers: { [Player]: boolean } = {}

local function playRewardVfx(position: Vector3)
	local vfx = REWARD_VFX_TEMPLATE:Clone()
	vfx.CFrame = CFrame.new(position)
	vfx.Parent = workspace

	-- Emit() is a fire-and-forget burst, not a replicated property - calling
	-- it in the same frame the instance is parented can race ahead of
	-- clients still receiving it over the network, so the burst fires into
	-- nothing. Give it a beat to replicate first.
	task.wait(0.1)

	for _, particle in vfx:GetDescendants() do
		if particle:IsA("ParticleEmitter") then
			particle:Emit(10)
		end
	end
	local lensFlare = vfx:FindFirstChild("Abstract Lens Flare")
	if lensFlare and lensFlare:IsA("ParticleEmitter") then
		lensFlare:Emit(20)
	end

	task.delay(2, function()
		vfx:Destroy()
	end)
end

local function startBeamFlash(beam: BasePart)
	beam.Transparency = BEAM_MIN_TRANSPARENCY
	TweenService:Create(beam, BEAM_FLASH_INFO, { Transparency = BEAM_MAX_TRANSPARENCY }):Play()
end

local function swapInEventSky()
	local currentSky = Lighting:FindFirstChildOfClass("Sky")
	if currentSky then
		originalSky = currentSky
		currentSky.Parent = nil
	end

	local eventSky = EVENT_SKY_TEMPLATE:Clone()
	eventSky.Name = "Sky"
	eventSky.Parent = Lighting
end

local function restoreOriginalSky()
	local currentSky = Lighting:FindFirstChildOfClass("Sky")
	if currentSky then
		currentSky:Destroy()
	end

	if originalSky then
		originalSky.Parent = Lighting
		originalSky = nil
	end
end

-- World1 keeps using the original unprefixed Functional path; World2/3 live
-- under their own top-level world root folders - same convention as
-- AutoWinsService.GetStagesRoot/WinsService.GetSpawnPosition.
local function GetUFOEventRoot(world: number): Instance
	if world == 1 then
		return workspace.Functional
	end
	local worldRoot = workspace:FindFirstChild("World" .. world)
	return (worldRoot and worldRoot:FindFirstChild("Functional")) or workspace.Functional
end

local function getRandomSpawnPosition(world: number): Vector3
	local worldConfig = UFOEventConfig.Worlds[world] or UFOEventConfig.Worlds[1]
	local worldUFOs = activeUFOs[world] or {}

	for _ = 1, 10 do
		local x = math.random(worldConfig.SpawnAreaMinX, worldConfig.SpawnAreaMaxX)
		local z = math.random(worldConfig.SpawnAreaMinZ, worldConfig.SpawnAreaMaxZ)
		local candidate = Vector3.new(x, worldConfig.SpawnHeight, z)

		local tooClose = false
		for _, entry in worldUFOs do
			if (entry.Model:GetPivot().Position - candidate).Magnitude < UFOEventConfig.MinSpawnSeparation then
				tooClose = true
				break
			end
		end
		if not tooClose then
			return candidate
		end
	end

	-- Gave up finding a clear spot after a few tries (pool is crowded) - spawn
	-- anyway rather than leaving the pool short.
	return Vector3.new(
		math.random(worldConfig.SpawnAreaMinX, worldConfig.SpawnAreaMaxX),
		worldConfig.SpawnHeight,
		math.random(worldConfig.SpawnAreaMinZ, worldConfig.SpawnAreaMaxZ)
	)
end

-- Drifts an unclaimed UFO between random points within the spawn area at a
-- constant speed, forever, until it's claimed, the event stops, or it's
-- destroyed - stops immediately either way (checked every Heartbeat) so the
-- ship holds still for the whole abduction sequence once someone's inside it.
local function wanderUFO(ufo: Model, claimedRef: { claimed: boolean }, world: number)
	local worldConfig = UFOEventConfig.Worlds[world] or UFOEventConfig.Worlds[1]
	task.spawn(function()
		while eventActive and ufo.Parent and not claimedRef.claimed do
			local currentPos = ufo:GetPivot().Position
			local targetPos = Vector3.new(
				math.random(worldConfig.SpawnAreaMinX, worldConfig.SpawnAreaMaxX),
				worldConfig.SpawnHeight,
				math.random(worldConfig.SpawnAreaMinZ, worldConfig.SpawnAreaMaxZ)
			)

			local duration = math.max((targetPos - currentPos).Magnitude / UFOEventConfig.WanderSpeed, 0.1)
			local startTime = os.clock()

			while eventActive and ufo.Parent and not claimedRef.claimed do
				local alpha = math.clamp((os.clock() - startTime) / duration, 0, 1)
				ufo:PivotTo(CFrame.new(currentPos:Lerp(targetPos, alpha)))
				if alpha >= 1 then break end
				RunService.Heartbeat:Wait()
			end
		end
	end)
end

local spawnUFO

local function removeUFO(ufo: Model, world: number)
	local worldUFOs = activeUFOs[world]
	if worldUFOs then
		for i, entry in worldUFOs do
			if entry.Model == ufo then
				entry.Connection:Disconnect()
				table.remove(worldUFOs, i)
				break
			end
		end
	end

	ufo:Destroy()
end

local function onBeamTouched(ufo: Model, hit: BasePart, claimedRef: { claimed: boolean }, world: number)
	if claimedRef.claimed then return end

	local character = hit.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player then return end

	if abductingPlayers[player] then return end

	local lastUse = lastAbductionTime[player]
	if lastUse and os.clock() - lastUse < UFOEventConfig.CooldownSeconds then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	local suckedPosition = ufo:FindFirstChild("PlayerSuckedPosition")
	if not suckedPosition then
		warn("UFOEventService: UFO is missing PlayerSuckedPosition - skipping abduction")
		return
	end
	local suckedWorldPosition = suckedPosition.Position

	claimedRef.claimed = true
	abductingPlayers[player] = true

	Net:RemoteEvent("AbductionStarted"):FireClient(player, suckedWorldPosition)

	-- Reward VFX bursts at the moment the character finishes rising into the
	-- beam - spawned server-side (unlike the character's own lift animation,
	-- which the client drives locally) so every nearby player sees it too.
	-- Uses the UFO's own PlayerSuckedPosition rather than the character's
	-- (client-driven, so not reliably in sync server-side) position.
	task.delay(UFOEventConfig.CharacterMovingUpDuration, function()
		if player.Parent then
			playRewardVfx(suckedWorldPosition)
		end
	end)

	-- The UFO despawns once the player has been fully sucked in and
	-- rewarded/teleported, not the moment they're claimed - it stays visible
	-- (and unusable by anyone else, via claimedRef) for the whole sequence.
	task.delay(UFOEventConfig.TotalSequenceDuration, function()
		removeUFO(ufo, world)
		-- Don't replenish the pool if the event's been stopped in the
		-- meantime - StopEvent already cleared everything else.
		if eventActive then
			spawnUFO(world)
		end

		abductingPlayers[player] = nil
		-- Restart the cooldown window from the teleport-back moment (not the
		-- original touch), so there's always at least CooldownSeconds of
		-- protection right after landing at spawn - otherwise a short
		-- cooldown counted from touch-time could already have lapsed by the
		-- time the sequence finishes.
		lastAbductionTime[player] = os.clock()

		if not player.Parent then return end

		local level = DataManager.Get(player, "Level") or 1
		local wins = UFOEventConfig.GetWinsForLevel(level)
		WinsService.GrantWins(player, wins)
	end)
end

spawnUFO = function(world: number)
	local position = getRandomSpawnPosition(world)

	local ufo = UFO_TEMPLATE:Clone()
	ufo:PivotTo(CFrame.new(position))
	ufo.Parent = ufoFolder[world]

	local beam = ufo:FindFirstChild("Parts") and ufo.Parts:FindFirstChild("Model") and ufo.Parts.Model:FindFirstChild("Beam")
	if not beam then
		warn("UFOEventService: UFO template is missing Parts.Model.Beam - skipping UFO event")
		ufo:Destroy()
		return
	end

	startBeamFlash(beam)

	local claimedRef = { claimed = false }
	local connection = beam.Touched:Connect(function(hit)
		onBeamTouched(ufo, hit, claimedRef, world)
	end)
	wanderUFO(ufo, claimedRef, world)

	activeUFOs[world] = activeUFOs[world] or {}
	table.insert(activeUFOs[world], { Model = ufo, Connection = connection, ClaimedRef = claimedRef })
end

-- Ticks the ActiveBoosts "Server" scope countdown (Workspace attribute) once
-- a second until duration elapses, then auto-stops the event - mirrors
-- ServerBoostService's os.time()-based remaining calc so it can't drift from
-- repeated task.wait(1) calls. Bails early (without the auto-stop) if
-- StopEvent already flipped eventActive off first.
local function runEventTimer()
	task.spawn(function()
		while eventActive do
			local remaining = math.max(0, expiresAt - os.time())
			Workspace:SetAttribute("UFOEventRemainingSeconds", remaining)

			if remaining <= 0 then
				break
			end
			task.wait(SYNC_INTERVAL)
		end

		if eventActive then
			UFOEventService.StopEvent()
		end
	end)
end

-- Spawns the UFO pool, starts wandering/claiming, swaps in the event sky, and
-- auto-stops after duration seconds. No-ops if already active. This (not
-- .Start()) is the entry point the EventManager will call.
function UFOEventService.StartEvent(duration: number)
	if eventActive then return end
	eventActive = true
	expiresAt = os.time() + duration

	for world = 1, 3 do
		local worldRoot = GetUFOEventRoot(world)
		local folder = worldRoot:FindFirstChild("UFOEvent")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "UFOEvent"
			folder.Parent = worldRoot
		end
		ufoFolder[world] = folder

		local worldConfig = UFOEventConfig.Worlds[world] or UFOEventConfig.Worlds[1]
		for _ = 1, worldConfig.MaxConcurrentUFOs do
			spawnUFO(world)
		end
	end

	swapInEventSky()
	runEventTimer()
end

-- Destroys every currently-spawned UFO and disconnects their Touched
-- connections (in-flight abductions, if any, are left to finish naturally -
-- the client already has its own cached target position and doesn't need the
-- UFO instance to still exist, and the pending reward grant checks
-- eventActive before spawning a replacement), restores the original sky, and
-- clears the ActiveBoosts countdown. No-ops if already inactive.
function UFOEventService.StopEvent()
	if not eventActive then return end
	eventActive = false

	for world = 1, 3 do
		local worldUFOs = activeUFOs[world]
		if worldUFOs then
			for _, entry in worldUFOs do
				entry.Connection:Disconnect()
				entry.Model:Destroy()
			end
			table.clear(worldUFOs)
		end

		local folder = ufoFolder[world]
		if folder then
			folder:Destroy()
			ufoFolder[world] = nil
		end
	end

	restoreOriginalSky()
	Workspace:SetAttribute("UFOEventRemainingSeconds", 0)
end

function UFOEventService.Start()
	Players.PlayerRemoving:Connect(function(player)
		lastAbductionTime[player] = nil
		abductingPlayers[player] = nil
	end)
end

return UFOEventService
