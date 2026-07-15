local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local PlusPercentSpeedConfig = require(ReplicatedStorage.Shared.Configs.PlusPercentSpeedConfig)
local NumberFormat = require(ReplicatedStorage.Shared.Packages.NumberFormat)

local LocalPlayer = Players.LocalPlayer

local OPTION_NAMES = { "FirstOption", "SecondOption", "ThirdOption" }

local PlusPercentSpeedController = {}

function PlusPercentSpeedController.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local feature = playerGui:WaitForChild("Main"):WaitForChild("Stats"):WaitForChild("PlusPercentSpeed")
	local playerData = LocalPlayer:WaitForChild("PlayerData")
	local speedValue = playerData:WaitForChild("Speed")

	local tierLabels: { [string]: TextLabel } = {}

	for _, optionName in OPTION_NAMES do
		local option = feature:FindFirstChild(optionName)
		if not option then continue end

		local button = option:FindFirstChildOfClass("ImageButton")
		local tierLabel = option:FindFirstChild("TierLabel")

		if tierLabel and tierLabel:IsA("TextLabel") then
			tierLabels[optionName] = tierLabel
		end

		if button then
			button.Activated:Connect(function()
				Net:RemoteEvent("RequestPlusPercentSpeed"):FireServer(optionName)
			end)
		end
	end

	local function refreshPreviews()
		local currentSpeed = speedValue.Value
		for optionName, tierLabel in tierLabels do
			local percent = PlusPercentSpeedConfig[optionName]
			if percent then
				local bonus = math.floor(currentSpeed * percent)
				tierLabel.Text = `+{NumberFormat.Format(bonus)} Speed`
			end
		end
	end

	speedValue:GetPropertyChangedSignal("Value"):Connect(refreshPreviews)
	refreshPreviews()
end

return PlusPercentSpeedController
