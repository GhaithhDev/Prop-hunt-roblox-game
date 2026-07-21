local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local NotificationConfig = require(ReplicatedStorage.Shared.Configs.NotificationConfig)
local ShrinkConfig = require(ReplicatedStorage.Shared.Configs.ShrinkConfig)

--//Packages
local SoundUtils = require(ReplicatedStorage.Shared.Packages.SoundUtils)

local LocalPlayer = Players.LocalPlayer

local NotificationsController = {}

local mainGui, template, levelUpTemplate

local function ensureLoaded()
	if template then return end
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	mainGui = playerGui:WaitForChild("Main")
	template = mainGui:WaitForChild("NotificationTemplate")
	levelUpTemplate = mainGui:WaitForChild("LevelNotification")
end

local function buildFadeTargets(clone: Instance): { { instance: Instance, property: string, restValue: number } }
	local targets = {}

	local function add(instance: Instance, property: string)
		table.insert(targets, { instance = instance, property = property, restValue = instance[property] })
	end

	if clone:IsA("Frame") then
		add(clone, "BackgroundTransparency")
	end

	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("Frame") then
			add(descendant, "BackgroundTransparency")
		elseif descendant:IsA("TextLabel") then
			add(descendant, "TextTransparency")
			add(descendant, "TextStrokeTransparency")
		elseif descendant:IsA("UIStroke") then
			add(descendant, "Transparency")
		end
	end

	return targets
end

local function hideFadeTargets(fadeTargets)
	for _, target in fadeTargets do
		target.instance[target.property] = 1
	end
end

local function tweenFadeTargets(fadeTargets, tweenInfo, showing: boolean)
	for _, target in fadeTargets do
		local goal = showing and target.restValue or 1
		TweenService:Create(target.instance, tweenInfo, { [target.property] = goal }):Play()
	end
end

function NotificationsController.Notify(mode: string, notificationText: string)
	ensureLoaded()

	local clone = template:Clone()
	local textLabel = clone:FindFirstChild("TextLabel")
	local uiStroke = textLabel and textLabel:FindFirstChildOfClass("UIStroke")

	textLabel.Text = notificationText
	local sound = (mode == "error") and  SoundService.SFX.FlashRed or SoundService.SFX.FlashGreen
	SoundUtils.PlayLocalSound(sound)
	textLabel.TextColor3 = (mode == "error") and NotificationConfig.ErrorColor or NotificationConfig.SuccessColor

	local restPosition = template.Position
	local startPosition = restPosition + UDim2.new(0, 0, NotificationConfig.RiseDuringFadeIn, 0)
	local endPosition = restPosition - UDim2.new(0, 0, NotificationConfig.RiseDuringFadeOut, 0)

	clone.Position = startPosition
	textLabel.TextTransparency = 1
	if uiStroke then uiStroke.Transparency = 1 end
	clone.Visible = true
	clone.Parent = mainGui

	local fadeInInfo = TweenInfo.new(NotificationConfig.FadeInTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(clone, fadeInInfo, { Position = restPosition }):Play()
	TweenService:Create(textLabel, fadeInInfo, { TextTransparency = 0 }):Play()
	if uiStroke then TweenService:Create(uiStroke, fadeInInfo, { Transparency = 0 }):Play() end

	task.delay(NotificationConfig.FadeInTime + NotificationConfig.HoldTime, function()
		local fadeOutInfo = TweenInfo.new(NotificationConfig.FadeOutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local fadeOutTween = TweenService:Create(clone, fadeOutInfo, { Position = endPosition })
		TweenService:Create(textLabel, fadeOutInfo, { TextTransparency = 1 }):Play()
		if uiStroke then TweenService:Create(uiStroke, fadeOutInfo, { Transparency = 1 }):Play() end
		fadeOutTween:Play()

		fadeOutTween.Completed:Once(function()
			clone:Destroy()
		end)
	end)
end

function NotificationsController.NotifyLevelUp(oldLevel: number, newLevel: number)
	ensureLoaded()

	local clone = levelUpTemplate:Clone()
	local levelLabel = clone:WaitForChild("LevelLabel")
	local shrinkLabel = clone:WaitForChild("ShrinkLabel")

	levelLabel.Text = `Level {oldLevel} => Level {newLevel}`
	shrinkLabel.Text = `Shrink {ShrinkConfig.GetShrinkScoreForLevel(oldLevel)} => Shrink {ShrinkConfig.GetShrinkScoreForLevel(newLevel)}`

	local fadeTargets = buildFadeTargets(clone)
	hideFadeTargets(fadeTargets)

	local restPosition = levelUpTemplate.Position
	local startPosition = restPosition + UDim2.new(0, 0, NotificationConfig.RiseDuringFadeIn, 0)
	local endPosition = restPosition - UDim2.new(0, 0, NotificationConfig.RiseDuringFadeOut, 0)

	clone.Position = startPosition
	clone.Visible = true
	clone.Parent = mainGui

	local fadeInInfo = TweenInfo.new(NotificationConfig.FadeInTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(clone, fadeInInfo, { Position = restPosition }):Play()
	tweenFadeTargets(fadeTargets, fadeInInfo, true)

	task.delay(NotificationConfig.FadeInTime + NotificationConfig.LevelHoldTime, function()
		local fadeOutInfo = TweenInfo.new(NotificationConfig.FadeOutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local fadeOutTween = TweenService:Create(clone, fadeOutInfo, { Position = endPosition })
		tweenFadeTargets(fadeTargets, fadeOutInfo, false)
		fadeOutTween:Play()

		fadeOutTween.Completed:Once(function()
			clone:Destroy()
		end)
	end)
end

function NotificationsController.Start()
	ensureLoaded()

	Net:Connect("Notify", function(mode, notificationText)
		NotificationsController.Notify(mode, notificationText)
	end)
end

return NotificationsController
