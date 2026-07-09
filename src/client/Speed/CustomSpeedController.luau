local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpeedConfig = require(ReplicatedStorage.Shared.Configs.SpeedConfig)
local Net = require(ReplicatedStorage.Shared.Packages.Net)

local LocalPlayer = Players.LocalPlayer

local CustomSpeedController = {}

local function GetMaxSpeed(levelValue)
	return SpeedConfig.GetSpeedForLevel(levelValue.Value)
end

local function HookCurrentSpeedDisplay(character, currentSpeedLabel,speedInput)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end

	local function UpdateCurrentSpeedLabel()
		currentSpeedLabel.Text = "current speed: " .. humanoid.WalkSpeed
		speedInput.PlaceholderText = tostring(humanoid.WalkSpeed)
	end

	humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(UpdateCurrentSpeedLabel)
	UpdateCurrentSpeedLabel()
end

function CustomSpeedController.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local speedSettings = playerGui:WaitForChild("Main"):WaitForChild("SpeedSettings")
	local maxSpeedLabel = speedSettings:WaitForChild("MaxSpeedLabel")
	local speedInput = speedSettings:WaitForChild("SpeedInput")
	local currentSpeedLabel = speedSettings:WaitForChild("CurretnSpeed")
	local applyButton = speedSettings:WaitForChild("Apply")

	local playerData = LocalPlayer:WaitForChild("PlayerData")
	local levelValue = playerData:WaitForChild("Level")

	local function UpdateMaxSpeedLabel()
		maxSpeedLabel.Text = "Max Speed: " .. GetMaxSpeed(levelValue)
	end

	levelValue:GetPropertyChangedSignal("Value"):Connect(UpdateMaxSpeedLabel)
	UpdateMaxSpeedLabel()

	LocalPlayer.CharacterAdded:Connect(function(character)
		HookCurrentSpeedDisplay(character, currentSpeedLabel,speedInput)
	end)
	if LocalPlayer.Character then
		HookCurrentSpeedDisplay(LocalPlayer.Character, currentSpeedLabel,speedInput)
	end

	applyButton.Activated:Connect(function()
		local desiredSpeed = tonumber(speedInput.Text)
		local maxSpeed = GetMaxSpeed(levelValue)

		if not desiredSpeed or desiredSpeed ~= desiredSpeed then
			warn(`CustomSpeedController: "{speedInput.Text}" is not a valid number`)
			return
		end

		if desiredSpeed < SpeedConfig.BaseSpeed or desiredSpeed > maxSpeed then
			warn(`CustomSpeedController: {desiredSpeed} is outside the allowed range {SpeedConfig.BaseSpeed}-{maxSpeed}`)
			return
		end

		Net:RemoteEvent("SetCustomSpeed"):FireServer(desiredSpeed)
	end)
end

return CustomSpeedController
