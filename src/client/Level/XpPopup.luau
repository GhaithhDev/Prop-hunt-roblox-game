local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local XpPerPress = require(ReplicatedStorage.Shared.Packages.XpPerPress)
local XpPopupConfig = require(ReplicatedStorage.Shared.Configs.XpPopupConfig)
local NumberFormat = require(ReplicatedStorage.Shared.Packages.NumberFormat)

local LocalPlayer = Players.LocalPlayer

local XpPopup = {}

local lastPopupTime = 0

local OFFSET_MAGNITUDES = { 0.001, 0.1 }
local BOUNCE_INFO = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local DRIFT_INFO = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local mainGui, popupTemplate

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

local function SpawnPopup()
	local clone = popupTemplate:Clone()
	local plusAmountLabel = clone:FindFirstChild("PlusAmount")
	if plusAmountLabel then
		plusAmountLabel.Text = "+" .. NumberFormat.Format(XpPerPress.GetAmountForLocalPlayer())
	end

	local basePosition = popupTemplate.Position
	local magnitude = OFFSET_MAGNITUDES[math.random(1, #OFFSET_MAGNITUDES)]
	local xDirection = (math.random(0, 1) == 0) and -1 or 1
	local xOffset = math.random(OFFSET_MAGNITUDES[1] * 100,OFFSET_MAGNITUDES[2] * 100) / 100 * xDirection
	local yOffset = -math.random(OFFSET_MAGNITUDES[1] * 100,OFFSET_MAGNITUDES[2] * 100) / 100
	yOffset -= .1
	local peakPosition = basePosition + UDim2.new(xOffset, 0, yOffset, 0)
	local driftPosition = peakPosition + UDim2.new(0, 0, magnitude * 0.5, 0)

	clone.Position = basePosition
	clone.Visible = true
	clone.Parent = mainGui

	local bounceTween = TweenService:Create(clone, BOUNCE_INFO, { Position = peakPosition })
	bounceTween:Play()
	bounceTween.Completed:Once(function()
		local driftTween = TweenService:Create(clone, DRIFT_INFO, { Position = driftPosition })
		driftTween:Play()
		FadeOutDescendants(clone, DRIFT_INFO)
		driftTween.Completed:Once(function()
			clone:Destroy()
		end)
	end)
end

function XpPopup.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	mainGui = playerGui:WaitForChild("Main")
	popupTemplate = mainGui:WaitForChild("+XpTemplate")

	local playerData = LocalPlayer:WaitForChild("PlayerData")
	local speedValue = playerData:WaitForChild("Speed")

	local lastSpeed = speedValue.Value
	speedValue:GetPropertyChangedSignal("Value"):Connect(function()
		local newSpeed = speedValue.Value
		local delta = newSpeed - lastSpeed
		lastSpeed = newSpeed
		if delta <= 0 then return end

		local now = os.clock()
		if now - lastPopupTime < XpPopupConfig.PopupCooldown then return end
		lastPopupTime = now

		SpawnPopup()
	end)
end

return XpPopup
