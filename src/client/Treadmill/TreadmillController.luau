local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local Tags = require(ReplicatedStorage.Shared.Configs.Tags)
local SoundUtils = require(ReplicatedStorage.Shared.Packages.SoundUtils)

local LocalPlayer = Players.LocalPlayer

local TreadmillController = {}

-- Keyed by TimerGui (not the treadmill Model - see note below), refreshed
-- every RenderStepped frame in Start() below.
--
-- Worlds are ~5k studs apart and StreamingEnabled is on, so a treadmill
-- Model itself always exists/stays tagged EventTreadmill regardless of
-- distance - only its descendants (parts, meshes, and this TimerGui) stream
-- in/out as a player gets close/far. That means CollectionService's added/
-- removed signals for Tags.EVENT_TREADMILL fire once per treadmill spawn/
-- despawn, not per stream-in/out - by the time "added" fires the GUI may not
-- have streamed in yet, and "removed" never fires just from walking out of
-- range. TimerGui itself is tagged Tags.EVENT_TREADMILL_TIMER instead, so
-- these signals track its actual streamed-in/out lifecycle directly.
type TimerEntry = { TimerText: TextLabel, Treadmill: Instance }
local eventTreadmillTimers: { [Instance]: TimerEntry } = {}

local function formatCountdown(remainingSeconds: number): string
	local minutes = math.floor(remainingSeconds / 60)
	local seconds = math.floor(remainingSeconds % 60)
	return string.format("%d:%02d", minutes, seconds)
end

-- Walks up from timerGui to find the ancestor tagged Tags.EVENT_TREADMILL -
-- Instance:FindFirstAncestorWithTag isn't in this project's Luau type defs,
-- so this does the same walk manually via CollectionService:HasTag.
local function findEventTreadmillAncestor(instance: Instance): Instance?
	local current = instance.Parent
	while current do
		if CollectionService:HasTag(current, Tags.EVENT_TREADMILL) then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function trackEventTreadmillTimer(timerGui: Instance)
	local timerText = timerGui:FindFirstChild("TimerText")
	if not (timerText and timerText:IsA("TextLabel")) then
		warn("TreadmillController: EventTreadmillTimer-tagged instance has no TimerText child - can't track it")
		return
	end

	-- The treadmill Model (still tagged Tags.EVENT_TREADMILL - see
	-- TreadmillService.SpawnEventTreadmill) carries the ExpiresAt attribute
	-- this timer counts down to.
	local treadmill = findEventTreadmillAncestor(timerGui)
	if not treadmill then
		warn("TreadmillController: EventTreadmillTimer-tagged instance has no EventTreadmill ancestor - can't track it")
		return
	end

	eventTreadmillTimers[timerGui] = { TimerText = timerText, Treadmill = treadmill }
end

local function untrackEventTreadmillTimer(timerGui: Instance)
	eventTreadmillTimers[timerGui] = nil
end

function TreadmillController.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local spawnButton = playerGui:WaitForChild("Main"):WaitForChild("LeftIcons")
	:WaitForChild("LeftIconsContainer"):WaitForChild("SpawnTreadmil"):WaitForChild("Button")

	spawnButton.Activated:Connect(function()
		Net:RemoteEvent("ToggleSpawn"):FireServer()
	end)

	CollectionService:GetInstanceAddedSignal(Tags.TREADMILL):Connect(function(instance)
		if instance:GetAttribute("OwnerId") == LocalPlayer.UserId then
			SoundUtils.PlayLocalSound(SoundService.SFX.PlacedownTreadmill)
		end
	end)

	for _, timerGui in CollectionService:GetTagged(Tags.EVENT_TREADMILL_TIMER) do
		trackEventTreadmillTimer(timerGui)
	end
	CollectionService:GetInstanceAddedSignal(Tags.EVENT_TREADMILL_TIMER):Connect(trackEventTreadmillTimer)
	CollectionService:GetInstanceRemovedSignal(Tags.EVENT_TREADMILL_TIMER):Connect(untrackEventTreadmillTimer)

	RunService.RenderStepped:Connect(function()
		local now = Workspace:GetServerTimeNow()
		for timerGui, entry in eventTreadmillTimers do
			if not timerGui.Parent then
				eventTreadmillTimers[timerGui] = nil
				continue
			end

			local expiresAt = entry.Treadmill:GetAttribute("ExpiresAt")
			if not expiresAt then
				continue
			end

			entry.TimerText.Text = formatCountdown(math.max(0, expiresAt - now))
		end
	end)
end

return TreadmillController
