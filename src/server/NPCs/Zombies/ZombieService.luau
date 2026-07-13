--[[
	ZombieService

	Spawns one zombie per Workspace.Functional.SpawnZombiePositions part and
	runs a simple 3-state behavior on top of PathfindingAgent:

	  Chasing          -> a player is inside the spawn point's AttackRange
	                      part; chase the closest one, kill on contact.
	  ReturningToSpawn -> no player in range; walk back to the spawn position.
	  Idle             -> arrived back at the spawn position; wait.

	Movement/spawn/despawn/loop plumbing lives in PathfindingAgent (shared
	with any future pathfinding NPC service); everything below is
	zombie-specific decision logic layered on top of it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local PathfindingAgent = require(script.Parent.Parent.PathfindingAgent)
local DeathService = require(ServerScriptService.Server.Death.DeathService)
local AnimationService = require(ServerScriptService.Server.Animation.AnimationService)

local NPCAssets = ReplicatedStorage.Shared.Assets.NPCs

-- Cadences
local THINK_INTERVAL_MIN = 0.08 -- target selection / state decision (randomized - staggers the horde)
local THINK_INTERVAL_MAX = 0.15
local LOCOMOTION_STEP = 0.05 -- steer / repath-staleness check / kill-box check

-- Movement/combat (placeholders - tune freely)
local REPATH_DISTANCE = 6 -- only recompute a path once the target has drifted this far (studs)
local ARRIVE_EPSILON = 1 -- treated as "arrived back at spawn"

local ZombieService = {}

local zombiesFolder: Folder

local function isInsideBox(position: Vector3, box: BasePart): boolean
	local halfSize = box.Size / 2
	local localPosition = box.CFrame:PointToObjectSpace(position)
	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Y) <= halfSize.Y
		and math.abs(localPosition.Z) <= halfSize.Z
end

-- Ignores Y - a zombie's root sits much higher off the ground than a
-- player's, so raw Vector3 distance stays large even when they're standing
-- right next to each other.
local function horizontalDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

-- Kills every player whose character overlaps the zombie's own bounding box
-- (contact-based, not a distance threshold).
local function killOverlappingPlayers(state)
	local boundingCFrame, boundingSize = state.model:GetBoundingBox()

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { state.model }

	local parts = workspace:GetPartBoundsInBox(boundingCFrame, boundingSize, params)
	for _, part in parts do
		local character = part:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if player then
			DeathService.KillPlayer(player, state.stageNumber)
		end
	end
end

local function isMovingMode(mode: string): boolean
	return mode == "Chasing" or mode == "ReturningToSpawn"
end

-- Only touches animations when "moving-ness" actually flips - Chasing and
-- ReturningToSpawn both keep ZombieWalk running uninterrupted since they're
-- both "moving" states.
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

-- Closest alive player whose root is inside this zombie's AttackRange part.
local function getClosestPlayerInRange(state): BasePart?
	local bestRoot: BasePart? = nil
	local bestDist = math.huge

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

		local dist = horizontalDistance(root.Position, state.root.Position)
		if dist < bestDist then
			bestDist = dist
			bestRoot = root
		end
	end

	return bestRoot
end

------------------------------------------------------------------------
-- THINK: pick target + decide state
------------------------------------------------------------------------

local function think(state)
	local root = state.root
	if not root or not root.Parent then return end

	-- Rebuilt every think so newly-joined players are excluded from LOS
	-- blocking, same as the crowd-exclude reasoning in PathfindingAgent.
	state._losParams = PathfindingAgent.BuildLosParams(state.model, { zombiesFolder })

	local target = getClosestPlayerInRange(state)
	if target then
		setMode(state, "Chasing")
		state.target = target
	elseif horizontalDistance(root.Position, state.spawnPosition) <= ARRIVE_EPSILON then
		setMode(state, "Idle")
		state.target = nil
	else
		setMode(state, "ReturningToSpawn")
		state.target = nil
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
		killOverlappingPlayers(state)
	elseif state.mode == "ReturningToSpawn" then
		PathfindingAgent.MoveToward(state, state.spawnPosition, { repathDistance = REPATH_DISTANCE })
	elseif state.mode == "Idle" then
		PathfindingAgent.StopPath(state)
	end
end

------------------------------------------------------------------------
-- SPAWN
------------------------------------------------------------------------

local function spawnZombieAt(part: BasePart)
	local modelName = part:GetAttribute("ModelName")
	local template = modelName and NPCAssets:FindFirstChild(modelName)
	if not template then
		warn(`ZombieService: "{part.Name}" has no valid ModelName ("{tostring(modelName)}" under Assets.NPCs) - skipping`)
		return
	end

	local attackRangeValue = part:FindFirstChild("AttackRange")
	local attackRangePart = attackRangeValue and attackRangeValue:IsA("ObjectValue") and attackRangeValue.Value
	if not attackRangePart or not attackRangePart:IsA("BasePart") then
		warn(`ZombieService: "{part.Name}" has no valid AttackRange BasePart - skipping`)
		return
	end

	local state = PathfindingAgent.SpawnNPC({
		template = template,
		name = part.Name,
		parent = zombiesFolder,
		spawnCFrame = CFrame.new(part.Position),
	})

	state.mode = "Idle"
	state.target = nil
	state.spawnPosition = part.Position
	state.attackRangePart = attackRangePart
	state.stageNumber = part:GetAttribute("Stage")
	state.thinkInterval = THINK_INTERVAL_MIN + math.random() * (THINK_INTERVAL_MAX - THINK_INTERVAL_MIN)

	-- Warm up both loops once (forces the tracks to load) then immediately
	-- silence them; explicitly resume Idle to match the starting state.mode -
	-- setMode only fires Play/Stop calls on an actual transition, so without
	-- this nothing would be playing at all until the first state change.
	AnimationService.Play(state.model, "ZombieIdle", true, Enum.AnimationPriority.Idle)
	AnimationService.Play(state.model, "ZombieWalk", true, Enum.AnimationPriority.Movement)
	AnimationService.Stop(state.model, "ZombieIdle")
	AnimationService.Stop(state.model, "ZombieWalk")
	AnimationService.Resume(state.model, "ZombieIdle")

	pcall(think, state) -- set a correct initial state before the loop starts
	task.spawn(PathfindingAgent.RunLoop, state, think, locomote, state.thinkInterval, LOCOMOTION_STEP)
end

function ZombieService.Start()
	zombiesFolder = workspace.Functional.Spawns:FindFirstChild("Zombies")
	if not zombiesFolder then
		zombiesFolder = Instance.new("Folder")
		zombiesFolder.Name = "Zombies"
		zombiesFolder.Parent = workspace.Functional.Spawns
	end

	for _, part in workspace.Functional.SpawnZombiePositions:GetChildren() do
		if part:IsA("BasePart") then
			spawnZombieAt(part)
		end
	end
end

return ZombieService
