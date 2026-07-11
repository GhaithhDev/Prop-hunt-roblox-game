local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local SoundUtils = require(ReplicatedStorage.Shared.Packages.SoundUtils)

local LocalPlayer = Players.LocalPlayer

local PopupController = {}

local BOUNCE_OFFSET = UDim2.new(0, 0, 0.6, 0)
local BOUNCE_IN_TIME = 0.45
local BOUNCE_OUT_TIME = 0.3
local BLUR_SIZE = 24
local BLUR_TIME = 0.3
local HOVER_SCALE = 1.08
local HOVER_TIME = 0.15

local blur: BlurEffect
local currentOpenFrame: Frame?
local restingPositions: { [Frame]: UDim2 } = {}
local activeTweens: { [Frame]: { Tween } } = {}

local function ensureBlur()
	if blur then return end
	blur = Lighting:WaitForChild("PopupBlur")
end

local function cancelTweens(frame: Frame)
	local tweens = activeTweens[frame]
	if not tweens then return end
	for _, tween in tweens do
		tween:Cancel()
	end
	activeTweens[frame] = nil
end

function PopupController.Open(frame: Frame)
	ensureBlur()

	if currentOpenFrame and currentOpenFrame ~= frame then
		PopupController.Close(currentOpenFrame)
	end

	cancelTweens(frame)

	local restingPosition = restingPositions[frame]
	frame.Position = restingPosition - BOUNCE_OFFSET
	frame.Visible = true
	SoundUtils.PlayLocalSound(SoundService.SFX.PopupOpen)

	local bounceTween = TweenService:Create(
		frame,
		TweenInfo.new(BOUNCE_IN_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = restingPosition }
	)
	bounceTween:Play()

	local blurTween = TweenService:Create(
		blur,
		TweenInfo.new(BLUR_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = BLUR_SIZE }
	)
	blurTween:Play()

	activeTweens[frame] = { bounceTween, blurTween }
	currentOpenFrame = frame
end

function PopupController.Close(frame: Frame)
	if not frame.Visible then return end

	ensureBlur()
	cancelTweens(frame)

	local restingPosition = restingPositions[frame]
	SoundUtils.PlayLocalSound(SoundService.SFX.PopupClose)

	local bounceTween = TweenService:Create(
		frame,
		TweenInfo.new(BOUNCE_OUT_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{ Position = restingPosition - BOUNCE_OFFSET }
	)
	bounceTween.Completed:Once(function()
		frame.Visible = false
	end)
	bounceTween:Play()

	local blurTween = TweenService:Create(
		blur,
		TweenInfo.new(BLUR_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Size = 0 }
	)
	blurTween:Play()

	activeTweens[frame] = { bounceTween, blurTween }

	if currentOpenFrame == frame then
		currentOpenFrame = nil
	end
end

local function ensureUIScale(icon: GuiButton): UIScale
	local uiScale = icon:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Scale = 1
		uiScale.Parent = icon
	end
	return uiScale
end

local function wireHover(icon: GuiButton)
	local uiScale = ensureUIScale(icon)

	icon.MouseEnter:Connect(function()
		TweenService:Create(
			uiScale,
			TweenInfo.new(HOVER_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = HOVER_SCALE }
		):Play()
	end)

	icon.MouseLeave:Connect(function()
		TweenService:Create(
			uiScale,
			TweenInfo.new(HOVER_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = 1 }
		):Play()
	end)
end

local function registerPopup(frame: Frame, icon: GuiButton, closeButton: GuiButton)
	restingPositions[frame] = frame.Position

	wireHover(icon)

	icon.Activated:Connect(function()
		if frame.Visible then
			PopupController.Close(frame)
		else
			PopupController.Open(frame)
		end
	end)

	closeButton.Activated:Connect(function()
		PopupController.Close(frame)
	end)
end

function PopupController.Start()
	ensureBlur()

	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local mainGui = playerGui:WaitForChild("Main")

	for _, frame in mainGui:GetChildren() do
		if not frame:IsA("Frame") then continue end

		local toggleButton = frame:FindFirstChild("ToggleButton")
		local closeButton = frame:FindFirstChild("CloseButton")
		if not (toggleButton and toggleButton:IsA("ObjectValue") and closeButton and closeButton:IsA("ObjectValue")) then
			continue
		end

		local icon = toggleButton.Value
		local closeInstance = closeButton.Value
		if not (icon and icon:IsA("GuiButton") and closeInstance and closeInstance:IsA("GuiButton")) then
			continue
		end

		registerPopup(frame, icon, closeInstance)
	end
end

return PopupController
