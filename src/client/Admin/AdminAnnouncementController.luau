local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local NotificationConfig = require(ReplicatedStorage.Shared.Configs.NotificationConfig)

local LocalPlayer = Players.LocalPlayer

local HOLD_TIME = 6

local AdminAnnouncementController = {}

-- Same generic fade-target pattern NotificationsController.NotifyLevelUp
-- uses, extended to also fade ImageLabel.ImageTransparency for the avatar.
local function buildFadeTargets(clone: Instance): { { instance: Instance, property: string, restValue: number } }
	local targets = {}

	local function add(instance: Instance, property: string)
		table.insert(targets, { instance = instance, property = property, restValue = instance[property] })
	end

	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("Frame") then
			add(descendant, "BackgroundTransparency")
		elseif descendant:IsA("TextLabel") then
			add(descendant, "TextTransparency")
			add(descendant, "TextStrokeTransparency")
		elseif descendant:IsA("UIStroke") then
			add(descendant, "Transparency")
		elseif descendant:IsA("ImageLabel") then
			add(descendant, "ImageTransparency")
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

function AdminAnnouncementController.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local mainGui = playerGui:WaitForChild("Main")
	local template = mainGui:WaitForChild("AdminAnnouncementTemplate")

	Net:Connect("AdminAnnouncement", function(playerName: string, userId: number, message: string)
		local clone = template:Clone()
		local textLabel = clone:FindFirstChild("TextLabel")
		local avatar = clone:FindFirstChild("Avatar")

		if textLabel then
			textLabel.Text = `{playerName}: {message}`
		end

		if avatar then
			task.spawn(function()
				local ok, content = pcall(function()
					return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
				end)
				if ok then
					avatar.Image = content
				end
			end)
		end

		local fadeTargets = buildFadeTargets(clone)
		hideFadeTargets(fadeTargets)

		local restPosition = template.Position
		local startPosition = restPosition + UDim2.new(0, 0, NotificationConfig.RiseDuringFadeIn, 0)
		local endPosition = restPosition - UDim2.new(0, 0, NotificationConfig.RiseDuringFadeOut, 0)

		clone.Position = startPosition
		clone.Visible = true
		clone.Parent = mainGui

		local fadeInInfo = TweenInfo.new(NotificationConfig.FadeInTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(clone, fadeInInfo, { Position = restPosition }):Play()
		tweenFadeTargets(fadeTargets, fadeInInfo, true)

		task.delay(NotificationConfig.FadeInTime + HOLD_TIME, function()
			local fadeOutInfo = TweenInfo.new(NotificationConfig.FadeOutTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			local fadeOutTween = TweenService:Create(clone, fadeOutInfo, { Position = endPosition })
			tweenFadeTargets(fadeTargets, fadeOutInfo, false)
			fadeOutTween:Play()

			fadeOutTween.Completed:Once(function()
				clone:Destroy()
			end)
		end)
	end)
end

return AdminAnnouncementController
