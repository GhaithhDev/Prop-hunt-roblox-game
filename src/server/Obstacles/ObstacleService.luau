--[[
	ObstacleService

	Spawns a repeating hazard on each Workspace.Functional.ObstaclePaths lane:
	clone ModelName's asset at StartCFrame and slide it via ReplicatedTween
	(smooth on every client, not just steppy server-tick-rate motion) through
	StartCFrame -> EndCFrame, or through an optional MidCFrame waypoint in
	between if the lane has one, at a constant Speed studs/sec - except the
	Start->Mid leg, which uses the lane's optional FirstPathSpeed instead of
	Speed if a MidCFrame is present and FirstPathSpeed is set. Kills any
	player it touches - same DeathService.KillPlayer path DeathParts and
	zombie contact already use, passing the lane's Stage attribute through so
	the Revive banner offers the right stage. If the lane's Reverse attribute
	is true, the obstacle slides back through the same waypoints (each
	segment at its own speed, in both directions) to StartCFrame after
	reaching the end instead of just despawning there.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local ReplicatedTween = require(ReplicatedStorage.Shared.Modules.ReplicatedTween)
local DeathService = require(ServerScriptService.Server.Death.DeathService)

local ObstacleAssets = ReplicatedStorage.Shared.Assets.Obstacles

-- Keyed by obstacle model name (not lane/folder) since e.g. Wall is reused by
-- more than one lane and should get the sound every time either spawns.
local PROXIMITY_SOUND_BY_MODEL = {
	ZombieWave = "Wave",
	Wall = "WallMoving",
	Ball = "WallMoving",
	RisingGround = "WallMoving",
}

local ObstacleService = {}

local obstaclesFolder: Folder

local function killTouchingPlayer(hit: BasePart, stageNumber: any)
	local character = hit.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player then return end

	DeathService.KillPlayer(player, stageNumber)
end

-- waypoints is the one-way path (Start -> [Mid ->] End); legSpeeds has one
-- entry per segment (#waypoints - 1) - lets a lane's optional FirstPathSpeed
-- give the Start->Mid leg a different speed than the rest. Reversing plays
-- back through the same waypoints/speeds in reverse instead of relying on
-- TweenInfo's native Reverses flag, since that can only bounce a single leg
-- back to its own start - it can't express a 3+ point path. Every leg is a
-- one-shot ReplicatedTween.Tween (RepeatCount=0, Reverses=false) chained via
-- task.delay, which keeps each leg phase-accurate for late-joining clients.
local function spawnObstacle(laneName: string, template: Model, waypoints: { CFrame }, legSpeeds: { number }, reverses: boolean, stageNumber: any)
	local clone = template:Clone()
	if not clone.PrimaryPart then
		clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart", true)
	end
	if not clone.PrimaryPart then
		warn(`ObstacleService: "{laneName}" template has no BasePart to move - skipping spawn`)
		clone:Destroy()
		return
	end

	clone:PivotTo(waypoints[1])
	clone.Parent = obstaclesFolder

	local proximitySoundName = PROXIMITY_SOUND_BY_MODEL[template.Name]
	local proximitySoundTemplate = proximitySoundName and SoundService.SFX.Proximity:FindFirstChild(proximitySoundName)
	if proximitySoundTemplate then
		local sound = proximitySoundTemplate:Clone()
		sound.Looped = true
		sound.Parent = clone.PrimaryPart
		sound:Play()
	end

	for _, part in clone:GetDescendants() do
		if part:IsA("BasePart") then
			part.Touched:Connect(function(hit)
				killTouchingPlayer(hit, stageNumber)
			end)
		end
	end

	local legs = waypoints
	local speeds = legSpeeds
	if reverses then
		legs = table.clone(waypoints)
		for i = #waypoints - 1, 1, -1 do
			table.insert(legs, waypoints[i])
		end

		-- Each physical segment keeps its own speed regardless of travel
		-- direction, so the return trip's speeds are the full forward list
		-- reversed (not trimmed like legs - there's no shared element here).
		speeds = table.clone(legSpeeds)
		for i = #legSpeeds, 1, -1 do
			table.insert(speeds, legSpeeds[i])
		end
	end

	local totalDuration = 0
	for i = 1, #legs - 1 do
		totalDuration += (legs[i + 1].Position - legs[i].Position).Magnitude / speeds[i]
	end

	local function playLeg(index: number)
		if index >= #legs then return end

		local legDuration = (legs[index + 1].Position - legs[index].Position).Magnitude / speeds[index]

		ReplicatedTween.Tween(
			clone.PrimaryPart,
			TweenInfo.new(legDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, false),
			{ CFrame = legs[index + 1] }
		)

		task.delay(legDuration, function()
			if clone.Parent then
				playLeg(index + 1)
			end
		end)
	end

	playLeg(1)

	task.delay(totalDuration, function()
		if clone.Parent then
			clone:Destroy()
		end
	end)
end

local function startLane(lane: Folder)
	local startPart = lane:FindFirstChild("StartCFrame")
	local endPart = lane:FindFirstChild("EndCFrame")
	if not (startPart and startPart:IsA("BasePart") and endPart and endPart:IsA("BasePart")) then
		warn(`ObstacleService: "{lane.Name}" is missing a valid StartCFrame/EndCFrame - skipping`)
		return
	end

	local modelName = lane:GetAttribute("ModelName")
	local template = modelName and ObstacleAssets:FindFirstChild(modelName)
	if not template or not template:IsA("Model") then
		warn(`ObstacleService: "{lane.Name}" has no valid ModelName ("{tostring(modelName)}" under Assets.Obstacles) - skipping`)
		return
	end

	local spawnRate = lane:GetAttribute("SpawnRate")
	local speed = lane:GetAttribute("Speed")
	if not spawnRate or not speed or speed <= 0 then
		warn(`ObstacleService: "{lane.Name}" is missing a valid SpawnRate/Speed - skipping`)
		return
	end

	local stageNumber = lane:GetAttribute("Stage")
	local reverses = lane:GetAttribute("Reverse") or false

	local midPart = lane:FindFirstChild("MidCFrame")
	local hasMid = midPart and midPart:IsA("BasePart")

	local waypoints: { CFrame } = hasMid
		and { startPart.CFrame, midPart.CFrame, endPart.CFrame }
		or { startPart.CFrame, endPart.CFrame }

	-- FirstPathSpeed is optional and only meaningful with a MidCFrame - lets
	-- the Start->Mid leg move at a different speed than the rest of the path
	-- (which stays at Speed). Falls back to Speed if unset/invalid.
	local legSpeeds: { number }
	if hasMid then
		local firstPathSpeed = lane:GetAttribute("FirstPathSpeed")
		local firstLegSpeed = (firstPathSpeed and firstPathSpeed > 0) and firstPathSpeed or speed
		legSpeeds = { firstLegSpeed, speed }
	else
		legSpeeds = { speed }
	end

	task.spawn(function()
		while true do
			spawnObstacle(lane.Name, template, waypoints, legSpeeds, reverses, stageNumber)
			task.wait(spawnRate)
		end
	end)
end

function ObstacleService.Start()
	obstaclesFolder = workspace.Functional.Spawns:FindFirstChild("Obstacles")
	if not obstaclesFolder then
		obstaclesFolder = Instance.new("Folder")
		obstaclesFolder.Name = "Obstacles"
		obstaclesFolder.Parent = workspace.Functional.Spawns
	end

	for _, lane in workspace.Functional.ObstaclePaths:GetChildren() do
		if lane:IsA("Folder") then
			startLane(lane)
		end
	end
end

return ObstacleService
