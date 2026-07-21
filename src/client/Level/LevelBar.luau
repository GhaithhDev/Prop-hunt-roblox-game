local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local LevelConfig = require(ReplicatedStorage.Shared.Configs.LevelConfig)
local NumberFormat = require(ReplicatedStorage.Shared.Packages.NumberFormat)
local SoundUtils = require(ReplicatedStorage.Shared.Packages.SoundUtils)

local LocalPlayer = Players.LocalPlayer

local NotificationsController = require(LocalPlayer.PlayerScripts.Client.Notifications.NotificationsController)

local LevelUpSound = SoundService.SFX.Levelup

local LevelBar = {}

local levelLabel, xpToNextLevelLabel, fillFrame, totalXpLabel
local fillYSize
local fillTween
local lastLevel

local function UpdateUI(shrinkValue, levelValue)
	local totalXp = shrinkValue.Value
	local currentLevel = levelValue.Value

	if lastLevel and currentLevel > lastLevel then
		SoundUtils.PlayLocalSound(LevelUpSound)
		NotificationsController.NotifyLevelUp(lastLevel, currentLevel)
	end
	lastLevel = currentLevel

	local currentThreshold = LevelConfig.GetXpRequiredForLevel(currentLevel)
	local nextThreshold = LevelConfig.GetXpRequiredForLevel(currentLevel + 1)
	local xpIntoLevel = totalXp - currentThreshold
	local xpNeededForLevel = nextThreshold - currentThreshold

	levelLabel.Text = "Level " .. currentLevel
	xpToNextLevelLabel.Text = NumberFormat.Format(xpIntoLevel) .. " / " .. NumberFormat.Format(xpNeededForLevel)
	totalXpLabel.Text = NumberFormat.Format(totalXp) .. " Shrink"

	local fraction = xpNeededForLevel > 0 and math.clamp(xpIntoLevel / xpNeededForLevel, 0, 1) or 1

	if fillTween then fillTween:Cancel() end
	fillTween = TweenService:Create(
		fillFrame,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.new(fraction, 0, fillYSize.Scale, fillYSize.Offset) }
	)
	fillTween:Play()
end

function LevelBar.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local statsFrame = playerGui:WaitForChild("Main"):WaitForChild("Stats")
	local levelBarFrame = statsFrame:WaitForChild("LevelBar")
	levelLabel = levelBarFrame:WaitForChild("Level")
	xpToNextLevelLabel = levelBarFrame:WaitForChild("XPToNextLevel")
	fillFrame = levelBarFrame:WaitForChild("Fill")
	totalXpLabel = statsFrame:WaitForChild("UpperContainer"):WaitForChild("TextLabel")
	fillYSize = fillFrame.Size.Y

	local playerData = LocalPlayer:WaitForChild("PlayerData")
	local shrinkValue = playerData:WaitForChild("Shrink")
	local levelValue = playerData:WaitForChild("Level")

	shrinkValue:GetPropertyChangedSignal("Value"):Connect(function()
		UpdateUI(shrinkValue, levelValue)
	end)
	levelValue:GetPropertyChangedSignal("Value"):Connect(function()
		UpdateUI(shrinkValue, levelValue)
	end)

	UpdateUI(shrinkValue, levelValue)
end

return LevelBar
