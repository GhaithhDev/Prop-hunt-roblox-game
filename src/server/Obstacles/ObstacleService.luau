--[[
	ObstacleService

	Spawns a repeating hazard on each Workspace.Functional.ObstaclePaths lane:
	clone ModelName's asset at StartCFrame, slide it in a straight line to
	EndCFrame at a constant Speed studs/sec via ReplicatedTween (smooth on
	every client, not just steppy server-tick-rate motion), and kill any
	player it touches - same DeathService.KillPlayer path DeathParts and
	zombie contact already use, passing the lane's Stage attribute through so
	the Revive banner offers the right stage. If the lane's Reverse attribute
	is true, the obstacle slides back to StartCFrame after reaching the end
	instead of just despawning there.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local ReplicatedTween = require(ReplicatedStorage.Shared.Modules.ReplicatedTween)
local DeathService = require(ServerScriptService.Server.Death.DeathService)

local ObstacleAssets = ReplicatedStorage.Shared.Assets.Obstacles

local ObstacleService = {}

local obstaclesFolder: Folder

local function killTouchingPlayer(hit: BasePart, stageNumber: any)
	local character = hit.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player then return end

	DeathService.KillPlayer(player, stageNumber)
end

local function spawnObstacle(laneName: string, template: Model, startCFrame: CFrame, endCFrame: CFrame, speed: number, reverses: boolean, stageNumber: any)
	local clone = template:Clone()
	if not clone.PrimaryPart then
		clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart", true)
	end
	if not clone.PrimaryPart then
		warn(`ObstacleService: "{laneName}" template has no BasePart to move - skipping spawn`)
		clone:Destroy()
		return
	end

	clone:PivotTo(startCFrame)
	clone.Parent = obstaclesFolder

	for _, part in clone:GetDescendants() do
		if part:IsA("BasePart") then
			part.Touched:Connect(function(hit)
				killTouchingPlayer(hit, stageNumber)
			end)
		end
	end

	local distance = (endCFrame.Position - startCFrame.Position).Magnitude
	local duration = distance / speed

	ReplicatedTween.Tween(
		clone.PrimaryPart,
		TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, 0, reverses),
		{ CFrame = endCFrame }
	)

	-- Reversing plays the same leg twice (there and back) - destroying the
	-- clone after only one leg's duration would pop it out of existence
	-- mid-reverse.
	local lifetime = reverses and (duration * 2) or duration
	task.delay(lifetime, function()
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
	local startCFrame = startPart.CFrame
	local endCFrame = endPart.CFrame

	task.spawn(function()
		while true do
			spawnObstacle(lane.Name, template, startCFrame, endCFrame, speed, reverses, stageNumber)
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
