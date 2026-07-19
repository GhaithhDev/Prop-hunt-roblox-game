--[[
	BossZombieService

	Fully independent sibling of ZombieService (same PathfindingAgent
	foundation, own decision logic) for boss-tier zombies: any
	Workspace.Functional.SpawnZombiePositions part with a BossCountdownSeconds
	attribute set is spawned and driven entirely by this service instead of
	ZombieService, which skips those parts.

	4-state behavior on top of PathfindingAgent:

	  Countdown        -> a player entered the AttackRange for the first time
	                      since Idle; frozen at spawn, announcing a
	                      once-per-second countdown to everyone currently in
	                      range. Cancels back to Idle immediately if they
	                      leave range before it finishes.
	  Chasing          -> countdown finished (or already released this
	                      encounter); chase the closest in-range player, kill
	                      on contact.
	  ReturningToSpawn -> no player in range; walk back to the spawn position.
	  Idle             -> arrived back at the spawn position; wait for the
	                      next Countdown trigger.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local SoundService = game:GetService("SoundService")

local PathfindingAgent = require(script.Parent.Parent.PathfindingAgent)
local DeathService = require(ServerScriptService.Server.Death.DeathService)
local AnimationService = require(ServerScriptService.Server.Animation.AnimationService)
local Net = require(ReplicatedStorage.Shared.Packages.Net)
local SoundUtils = require(ReplicatedStorage.Shared.Packages.SoundUtils)

local NPCAssets = ReplicatedStorage.Shared.Assets.NPCs

-- Cadences (same values as ZombieService - independent copies, not shared,
-- consistent with how ZombieService/TreadmillService each keep their own
-- small pure-math helpers rather than a shared utility module).
local THINK_INTERVAL_MIN = 0.08
local THINK_INTERVAL_MAX = 0.15
local LOCOMOTION_STEP = 0.1
local STOMP_INTERVAL = 0.5 -- Boss Stomp proximity ping cadence while Chasing

local REPATH_DISTANCE = 6
local ARRIVE_EPSILON = 1

local BossZombieService = {}

local zombiesFolder: Folder

local function isInsideBox(position: Vector3, box: BasePart): boolean
	local halfSize = box.Size / 2
	local localPosition = box.CFrame:PointToObjectSpace(position)
	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Y) <= halfSize.Y
		and math.abs(localPosition.Z) <= halfSize.Z
end

local function horizontalDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

local function killTouchingPlayer(hit: BasePart, stageNumber: any)
	local character = hit.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player then return end

	DeathService.KillPlayer(player, stageNumber)
end

local function isMovingMode(mode: string): boolean
	return mode == "Chasing" or mode == "ReturningToSpawn"
end

-- Countdown behaves like Idle animation-wise (frozen, no movement) - only
-- Chasing/ReturningToSpawn count as "moving".
local function setMode(state, newMode: string)
	if state.mode == newMode then return end

	local wasMoving = isMovingMode(state.mode)
	local isMoving = isMovingMode(newMode)
	state.mode = newMode

	if isMoving and not wasMoving then
		AnimationService.Stop(state.model, "ZombieIdle")
		AnimationService.Resume(state.model, "ZombieWalk")
	elseif not isMoving and wasMoving then
		AnimationService.Stop(state.model, "ZombieWalk")
		AnimationService.Resume(state.model, "ZombieIdle")
	end
end

local function getPlayersInRange(state): { { player: Player, root: BasePart } }
	local result = {}

	for _, plr in Players:GetPlayers() do
		local character = plr.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not (humanoid and root) or humanoid.Health <= 0 then
			continue
		end
		if not isInsideBox(root.Position, state.attackRangePart) then
			continue
		end

		table.insert(result, { player = plr, root = root })
	end

	return result
end

local function getClosestPlayerInRange(state): BasePart?
	local bestRoot: BasePart? = nil
	local bestDist = math.huge

	for _, entry in getPlayersInRange(state) do
		local dist = horizontalDistance(entry.root.Position, state.root.Position)
		if dist < bestDist then
			bestDist = dist
			bestRoot = entry.root
		end
	end

	return bestRoot
end

------------------------------------------------------------------------
-- THINK: pick target + decide state, including the Countdown warmup
------------------------------------------------------------------------

-- 4 explicit states (state.mode): "Idle", "Countdown", "Chasing",
-- "ReturningToSpawn". Each is an exclusive, self-contained block ending in
-- `return` with its own entry/exit conditions - only one ever runs per
-- tick, no shared/fallthrough logic to reason about.
local function think(state)
	local root = state.root
	if not root or not root.Parent then return end

	state._losParams = PathfindingAgent.BuildLosParams(state.model, { zombiesFolder })
	local target = getClosestPlayerInRange(state)

	if state.mode == "Idle" then
		-- Exit: a player enters range -> arm the Countdown warmup.
		if target then
			state.bossCountdownRemaining = state.bossCountdownSeconds
			-- Backdated so the very next Countdown tick's ">= 1" check fires
			-- the first announcement right away instead of waiting a full
			-- second for it.
			state.bossCountdownLastTick = os.clock() - 1
			setMode(state, "Countdown")
		end
		return
	end

	if state.mode == "Countdown" then
		-- Exit: the player(s) that triggered this left range -> cancel back
		-- to Idle. Checked every tick (not just once a second) so leaving
		-- mid-countdown cancels within one think tick, not up to a second
		-- later.
		if not target then
			state.bossCountdownRemaining = nil
			state.bossCountdownLastTick = nil
			setMode(state, "Idle")
			return
		end

		-- Gate both the announcement and the eventual release to the same
		-- once-per-real-second cadence, so "1" gets the same full second of
		-- hold time as every other number before the next event fires -
		-- otherwise the release (and the BossIsChasing popup it triggers)
		-- would fire on the very next think tick after "1" is announced,
		-- overlapping the still-animating BossIncomingFrame popup client-side.
		local now = os.clock()
		if now - state.bossCountdownLastTick >= 1 then
			state.bossCountdownLastTick = now

			-- Exit: countdown finished -> release into Chasing.
			if state.bossCountdownRemaining <= 0 then
				state.bossCountdownRemaining = nil
				state.bossCountdownLastTick = nil
				state.target = target
				for _, entry in getPlayersInRange(state) do
					Net:RemoteEvent("BossReleased"):FireClient(entry.player)
				end
				setMode(state, "Chasing")
				return
			end

			-- Still counting down: announce to everyone currently in range.
			for _, entry in getPlayersInRange(state) do
				Net:RemoteEvent("BossCountdown"):FireClient(entry.player, state.bossName, state.bossCountdownRemaining)
			end
			state.bossCountdownRemaining -= 1
		end
		return
	end

	if state.mode == "Chasing" then
		-- Exit: target lost -> Idle if already back home, else ReturningToSpawn.
		if not target then
			state.target = nil
			if horizontalDistance(root.Position, state.spawnPosition) <= ARRIVE_EPSILON then
				setMode(state, "Idle")
			else
				setMode(state, "ReturningToSpawn")
			end
			return
		end

		-- Still has a target: keep chasing the current closest one.
		state.target = target

		-- Proximity heartbeat while actively chasing, twice per real second.
		local now = os.clock()
		if now - (state.lastStompTick or 0) >= STOMP_INTERVAL then
			state.lastStompTick = now
			local stompSound = SoundService.SFX["Boss Stomp"]
			SoundUtils.PlayProximitySound(root.Position, stompSound.SoundId, {
				RollOffMinDistance = stompSound.RollOffMinDistance,
				RollOffMaxDistance = stompSound.RollOffMaxDistance,
				Volume = stompSound.Volume,
			})
		end
		return
	end

	if state.mode == "ReturningToSpawn" then
		-- Exit: a player re-enters range -> resume Chasing directly (no
		-- Countdown re-trigger - that only fires from a full Idle stop).
		if target then
			state.target = target
			setMode(state, "Chasing")
			return
		end

		-- Exit: arrived back at the spawn position -> Idle.
		if horizontalDistance(root.Position, state.spawnPosition) <= ARRIVE_EPSILON then
			setMode(state, "Idle")
		end
		return
	end
end

------------------------------------------------------------------------
-- LOCOMOTE: move / attack (runs more often than think)
------------------------------------------------------------------------

local function locomote(state)
	local root = state.root
	if not root or not root.Parent then return end
	local humanoid = state.humanoid
	if not humanoid or humanoid.Health <= 0 then return end

	if state.mode == "Chasing" then
		local target = state.target
		if not (target and target.Parent) then return end

		PathfindingAgent.MoveToward(state, target.Position, { repathDistance = REPATH_DISTANCE })
	elseif state.mode == "ReturningToSpawn" then
		PathfindingAgent.MoveToward(state, state.spawnPosition, { repathDistance = REPATH_DISTANCE })
	elseif state.mode == "Idle" then
		PathfindingAgent.StopPath(state)
	end
	-- Countdown: no movement, same as Idle - just don't touch the path.
end

------------------------------------------------------------------------
-- SPAWN
------------------------------------------------------------------------

local function getAgentRadius(model: Model)
	return model:GetExtentsSize().X / 2
end

local function getAgentHeight(model: Model)
	return model:GetExtentsSize().Y
end

local function spawnBossZombieAt(part: BasePart)
	local modelName = part:GetAttribute("ModelName")
	local template = modelName and NPCAssets:FindFirstChild(modelName)
	if not template then
		warn(`BossZombieService: "{part.Name}" has no valid ModelName ("{tostring(modelName)}" under Assets.NPCs) - skipping`)
		return
	end

	local attackRangeValue = part:FindFirstChild("AttackRange")
	local attackRangePart = attackRangeValue and attackRangeValue:IsA("ObjectValue") and attackRangeValue.Value
	if not attackRangePart or not attackRangePart:IsA("BasePart") then
		warn(`BossZombieService: "{part.Name}" has no valid AttackRange BasePart - skipping`)
		return
	end

	local params = {
		AgentRadius = getAgentRadius(template),
		AgentHeight = getAgentHeight(template),
		AgentCanJump = true,
		AgentCanClimb = false,
		WaypointSpacing = 4,
	}

	local state = PathfindingAgent.SpawnNPC({
		template = template,
		name = part.Name,
		parent = zombiesFolder,
		spawnCFrame = CFrame.new(part.Position),
		agentParams = params,
	})

	state.mode = "Idle"
	state.target = nil
	state.spawnPosition = part.Position
	state.attackRangePart = attackRangePart
	state.stageNumber = part:GetAttribute("Stage")
	state.thinkInterval = THINK_INTERVAL_MIN + math.random() * (THINK_INTERVAL_MAX - THINK_INTERVAL_MIN)

	state.bossName = part:GetAttribute("BossName") or "Zombie Boss"
	state.bossCountdownSeconds = part:GetAttribute("BossCountdownSeconds")
	state.bossCountdownRemaining = nil
	state.bossCountdownLastTick = nil
	state.lastStompTick = nil

	for _, descendant in state.model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Touched:Connect(function(hit)
				killTouchingPlayer(hit, state.stageNumber)
			end)
		end
	end

	AnimationService.Play(state.model, "ZombieIdle", true, Enum.AnimationPriority.Idle)
	AnimationService.Play(state.model, "ZombieWalk", true, Enum.AnimationPriority.Movement)
	AnimationService.Stop(state.model, "ZombieIdle")
	AnimationService.Stop(state.model, "ZombieWalk")
	AnimationService.Resume(state.model, "ZombieIdle")

	pcall(think, state)
	task.spawn(PathfindingAgent.RunLoop, state, think, locomote, state.thinkInterval, LOCOMOTION_STEP)
end

function BossZombieService.Start()
	zombiesFolder = workspace.Functional.Spawns:FindFirstChild("Zombies")
	if not zombiesFolder then
		zombiesFolder = Instance.new("Folder")
		zombiesFolder.Name = "Zombies"
		zombiesFolder.Parent = workspace.Functional.Spawns
	end

	for _, part in workspace.Functional.SpawnZombiePositions:GetChildren() do
		if part:IsA("BasePart") and part:GetAttribute("BossCountdownSeconds") then
			spawnBossZombieAt(part)
		end
	end
end

return BossZombieService
