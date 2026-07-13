--[[
	ReplicatedTween

	Server-authored, client-smooth tween replication. The server never plays
	a real tween on the instance itself - it drops a lightweight marker
	Instance (tween info + a server-synced start time) into a replicated
	folder, and each client plays its own local TweenService tween timed off
	that start time, catching up smoothly instead of stepping at the network
	replication rate.

	Required independently on both realms (like every src/shared/Modules
	file) and branches with RunService:IsServer()/IsClient(). Server-only:
	ReplicatedTween.Tween / .Cancel. Everything else is internal client-side
	catch-up logic.

	Scoped to one-shot tweens (RepeatCount = 0, Reverses = false) for exact
	elapsed-time catch-up - the common case. Repeating/reversing tweens still
	replicate and play, just without phase-accurate resume: every client
	starts an equivalent fresh tween immediately instead of computing which
	cycle/direction it should already be mid-way into.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ReplicatedTween = {}

local GOAL_ATTRIBUTE_PREFIX = "Goal_"

local activeClientTweens: { [Configuration]: Tween } = {}

local function isOneShot(repeatCount: number, reverses: boolean): boolean
	return repeatCount == 0 and not reverses
end

local function readGoal(marker: Configuration): { [string]: any }
	local goal = {}
	for attributeName, value in marker:GetAttributes() do
		local propertyName = attributeName:match("^" .. GOAL_ATTRIBUTE_PREFIX .. "(.+)$")
		if propertyName then
			goal[propertyName] = value
		end
	end
	return goal
end

local function applyGoal(instance: Instance, goal: { [string]: any })
	for property, value in goal do
		(instance :: any)[property] = value
	end
end

------------------------------------------------------------------------
-- CLIENT: catch-up playback
------------------------------------------------------------------------

local function onMarkerAdded(marker: Instance)
	if not marker:IsA("Configuration") then return end

	local targetValue = marker:FindFirstChild("Target")
	local target = targetValue and targetValue:IsA("ObjectValue") and targetValue.Value
	if not target then return end

	local goal = readGoal(marker)
	local easingStyle = Enum.EasingStyle[marker:GetAttribute("EasingStyle") or "Linear"]
	local easingDirection = Enum.EasingDirection[marker:GetAttribute("EasingDirection") or "Out"]
	local time = marker:GetAttribute("Time") or 0
	local repeatCount = marker:GetAttribute("RepeatCount") or 0
	local reverses = marker:GetAttribute("Reverses") or false
	local delayTime = marker:GetAttribute("DelayTime") or 0
	local startTime = marker:GetAttribute("StartTime") or Workspace:GetServerTimeNow()

	local function play(tweenTime: number)
		if tweenTime <= 0 then
			applyGoal(target, goal)
			return
		end

		local tween = TweenService:Create(
			target,
			TweenInfo.new(tweenTime, easingStyle, easingDirection, repeatCount, reverses, 0),
			goal
		)
		activeClientTweens[marker] = tween
		tween:Play()
	end

	local elapsed = Workspace:GetServerTimeNow() - startTime - delayTime

	if elapsed < 0 then
		-- Still in its delay window - wait it out, then play the full tween.
		task.delay(-elapsed, function()
			if marker.Parent then
				play(time)
			end
		end)
	elseif isOneShot(repeatCount, reverses) then
		-- Exact catch-up: same style/direction, shortened to what's left.
		play(time - elapsed)
	else
		-- Repeating/reversing: no phase-accurate resume, just start fresh.
		play(time)
	end

	marker.Destroying:Connect(function()
		local tween = activeClientTweens[marker]
		if tween then
			tween:Cancel()
			activeClientTweens[marker] = nil
		end
	end)
end

------------------------------------------------------------------------
-- SETUP (module load time, not .Start() - see file header/plan for why:
-- other services' Start() calls race this one, so ReplicatedTween.Tween
-- must be safely callable regardless of init order)
------------------------------------------------------------------------

local tweensFolder: Folder

if RunService:IsServer() then
	tweensFolder = Instance.new("Folder")
	tweensFolder.Name = "ReplicatedTweens"
	tweensFolder.Parent = ReplicatedStorage
else
	tweensFolder = ReplicatedStorage:WaitForChild("ReplicatedTweens")
	for _, marker in tweensFolder:GetChildren() do
		onMarkerAdded(marker)
	end
	tweensFolder.ChildAdded:Connect(onMarkerAdded)
end

------------------------------------------------------------------------
-- SERVER: public API
------------------------------------------------------------------------

function ReplicatedTween.Tween(instance: Instance, tweenInfo: TweenInfo, goal: { [string]: any }): Configuration
	assert(RunService:IsServer(), "ReplicatedTween.Tween can only be called from the server")

	local marker = Instance.new("Configuration")
	marker.Name = "Tween"

	local target = Instance.new("ObjectValue")
	target.Name = "Target"
	target.Value = instance
	target.Parent = marker

	marker:SetAttribute("StartTime", Workspace:GetServerTimeNow())
	marker:SetAttribute("Time", tweenInfo.Time)
	marker:SetAttribute("EasingStyle", tweenInfo.EasingStyle.Name)
	marker:SetAttribute("EasingDirection", tweenInfo.EasingDirection.Name)
	marker:SetAttribute("RepeatCount", tweenInfo.RepeatCount)
	marker:SetAttribute("Reverses", tweenInfo.Reverses)
	marker:SetAttribute("DelayTime", tweenInfo.DelayTime)

	for property, value in goal do
		marker:SetAttribute(GOAL_ATTRIBUTE_PREFIX .. property, value)
	end

	marker.Parent = tweensFolder

	-- No real tween runs server-side, so the authoritative properties only
	-- need to actually reach the goal once the tween is logically done -
	-- keeps server-side reads of `instance` correct, and means a late
	-- joiner just sees the finished state via normal replication instead of
	-- a stale marker. Every finite tween (any RepeatCount >= 0, reversing or
	-- not) has a well-defined total duration, so all of them get cleaned up -
	-- only RepeatCount == -1 (infinite) has no "done" time and is skipped;
	-- Cancel is the only way to remove those markers. A reversing tween's
	-- final resting value is back at its ORIGINAL value, not `goal`, so the
	-- goal is only actually applied when it doesn't reverse.
	if tweenInfo.RepeatCount ~= -1 then
		local cycles = tweenInfo.RepeatCount + 1
		local perCycleDuration = tweenInfo.Time * (tweenInfo.Reverses and 2 or 1)
		local totalDuration = tweenInfo.DelayTime + perCycleDuration * cycles

		task.delay(totalDuration, function()
			if marker.Parent then
				if not tweenInfo.Reverses then
					applyGoal(instance, goal)
				end
				marker:Destroy()
			end
		end)
	end

	return marker
end

function ReplicatedTween.Cancel(marker: Configuration)
	assert(RunService:IsServer(), "ReplicatedTween.Cancel can only be called from the server")
	if marker then
		marker:Destroy()
	end
end

return ReplicatedTween
