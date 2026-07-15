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

-- Workspace.Functional.OpenFrames.<Name> parts trigger Main.<Name> open on
-- approach - default radius, overridable per-part via an optional "Radius"
-- attribute (same attribute-driven convention as ObstaclePaths/TreadmillService).
local DEFAULT_PROXIMITY_RADIUS = 10
local PROXIMITY_CHECK_INTERVAL = 0.25

local blur: BlurEffect
local currentOpenFrame: Frame?
local restingPositions: { [Frame]: UDim2 } = {}
local activeTweens: { [Frame]: { Tween } } = {}

-- True only while a frame is open *because* the player walked into its
-- OpenFrames trigger zone - lets leaving the zone auto-close it, without
-- also closing a frame the player opened manually (icon click) while
-- standing in the same zone.
local openedByProximity: { [Frame]: boolean } = {}

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

-- icon is optional - a frame with a valid CloseButton but no (or an unset)
-- ToggleButton still gets its resting position captured and its close button
-- wired, so PopupController.Open/.Close work when driven externally (e.g. a
-- keybind-only panel like AdminPanel), it just has no icon to hover/click.
local function registerPopup(frame: Frame, closeButton: GuiButton, icon: GuiButton?)
	restingPositions[frame] = frame.Position

	if icon then
		wireHover(icon)

		icon.Activated:Connect(function()
			openedByProximity[frame] = false
			if frame.Visible then
				PopupController.Close(frame)
			else
				PopupController.Open(frame)
			end
		end)
	end

	closeButton.Activated:Connect(function()
		PopupController.Close(frame)
	end)
end

-- Workspace.Functional.OpenFrames.<Name> parts (marker parts, same
-- convention as SpawnZombiePositions/ObstaclePaths) open Main.<Name> when
-- the player walks within range - only parts whose name matches an
-- already-registered popup (present in restingPositions) are wired.
local function startProximityTriggers(mainGui: Instance)
	local openFramesFolder = workspace:FindFirstChild("Functional") and workspace.Functional:FindFirstChild("OpenFrames")
	if not openFramesFolder then return end

	local triggers: { { Part: BasePart, Frame: Frame } } = {}
	for _, part in openFramesFolder:GetChildren() do
		if not part:IsA("BasePart") then continue end
		local frame = mainGui:FindFirstChild(part.Name)
		if frame and frame:IsA("Frame") and restingPositions[frame] then
			table.insert(triggers, { Part = part, Frame = frame })
		end
	end
	if #triggers == 0 then return end

	local playerInsideZone: { [BasePart]: boolean } = {}

	task.spawn(function()
		while true do
			local character = LocalPlayer.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")

			for _, trigger in triggers do
				local part, frame = trigger.Part, trigger.Frame
				local wasInside = playerInsideZone[part] or false
				local radius = part:GetAttribute("Radius") or DEFAULT_PROXIMITY_RADIUS
				local isInside = rootPart ~= nil and (rootPart.Position - part.Position).Magnitude <= radius

				if isInside and not wasInside then
					if not frame.Visible then
						openedByProximity[frame] = true
						PopupController.Open(frame)
					end
				elseif not isInside and wasInside then
					if openedByProximity[frame] then
						PopupController.Close(frame)
						openedByProximity[frame] = false
					end
				end

				playerInsideZone[part] = isInside
			end

			task.wait(PROXIMITY_CHECK_INTERVAL)
		end
	end)
end

function PopupController.Start()
	ensureBlur()

	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local mainGui = playerGui:WaitForChild("Main")

	for _, frame in mainGui:GetChildren() do
		if not frame:IsA("Frame") then continue end

		local closeButton = frame:FindFirstChild("CloseButton")
		local closeInstance = closeButton and closeButton:IsA("ObjectValue") and closeButton.Value
		if not (closeInstance and closeInstance:IsA("GuiButton")) then
			continue
		end

		local toggleButton = frame:FindFirstChild("ToggleButton")
		local icon = toggleButton and toggleButton:IsA("ObjectValue") and toggleButton.Value
		if not (icon and icon:IsA("GuiButton")) then
			icon = nil
		end

		registerPopup(frame, closeInstance, icon)
	end

	startProximityTriggers(mainGui)
end

return PopupController
