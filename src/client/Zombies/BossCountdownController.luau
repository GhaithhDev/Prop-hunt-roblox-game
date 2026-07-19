local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local SoundUtils = require(ReplicatedStorage.Shared.Packages.SoundUtils)

local LocalPlayer = Players.LocalPlayer

local BossCountdownController = {}

local BOUNCE_IN = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FADE_OUT = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local incomingFrame, chasingFrame
local restSizes = {}
local generation = {} -- [frame] = number, bumped each playPopup call

local function FadeOutDescendants(instance, tweenInfo)
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("ImageLabel") then
			TweenService:Create(descendant, tweenInfo, { ImageTransparency = 1 }):Play()
		elseif descendant:IsA("TextLabel") then
			TweenService:Create(descendant, tweenInfo, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		elseif descendant:IsA("UIStroke") then
			TweenService:Create(descendant, tweenInfo, { Transparency = 1 }):Play()
		end
	end
end

local function ResetTransparency(instance)
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("ImageLabel") then
			descendant.ImageTransparency = 0
		elseif descendant:IsA("TextLabel") then
			descendant.TextTransparency = 0
			descendant.TextStrokeTransparency = 1
		elseif descendant:IsA("UIStroke") then
			descendant.Transparency = 0
		end
	end
end

-- Both frames are real, single, persistent Studio instances (not templates
-- to clone) - each call resets Size/transparency back to a clean starting
-- state up front rather than relying on :Destroy() to discard stale tween
-- state from a previous cycle.
--
-- If a new call comes in before the previous cycle's delayed callbacks have
-- finished (server tick jitter/network delivery timing can easily cause
-- this, since one full cycle's animation length matches the server's
-- 1-second countdown cadence with ~no slack), the OLD cycle's tween still
-- completes and fires its own Completed callback on its own schedule -
-- without this guard, that stale chain's FadeOutDescendants/Visible=false
-- calls fire after the NEW content is already showing, hiding/fading the
-- wrong (newer) number. The generation token makes a superseded chain's
-- delayed steps no-ops instead.
local function playPopup(frame, holdDuration: number)
	local myGeneration = (generation[frame] or 0) + 1
	generation[frame] = myGeneration

	frame.Size = UDim2.new(0, 0, 0, 0)
	ResetTransparency(frame)
	frame.Visible = true

	local growTween = TweenService:Create(frame, BOUNCE_IN, { Size = restSizes[frame] })
	growTween:Play()
	growTween.Completed:Once(function()
		if generation[frame] ~= myGeneration then return end
		task.wait(holdDuration)
		if generation[frame] ~= myGeneration then return end
		FadeOutDescendants(frame, FADE_OUT)
		task.delay(FADE_OUT.Time, function()
			if generation[frame] ~= myGeneration then return end
			frame.Visible = false
		end)
	end)
end

local function OnBossCountdown(bossName: string, secondsLeft: number)
	SoundUtils.PlayLocalSound(SoundService.SFX.Count)
	incomingFrame.TextLabel.Text = `⚠️ BOSS INCOMING {secondsLeft} ⚠️`
	playPopup(incomingFrame, 0.5)
end

local function OnBossReleased()
	SoundUtils.PlayLocalSound(SoundService.SFX.Count)
	playPopup(chasingFrame, 1)
end

function BossCountdownController.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local mainGui = playerGui:WaitForChild("Main")
	incomingFrame = mainGui:WaitForChild("BossIncomingFrame")
	chasingFrame = mainGui:WaitForChild("BossIsChasing")

	restSizes[incomingFrame] = incomingFrame.Size
	restSizes[chasingFrame] = chasingFrame.Size

	Net:Connect("BossCountdown", OnBossCountdown)
	Net:Connect("BossReleased", OnBossReleased)
end

return BossCountdownController
