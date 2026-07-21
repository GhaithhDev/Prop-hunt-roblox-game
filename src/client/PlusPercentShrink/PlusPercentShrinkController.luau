local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local PlusPercentShrinkConfig = require(ReplicatedStorage.Shared.Configs.PlusPercentShrinkConfig)
local NumberFormat = require(ReplicatedStorage.Shared.Packages.NumberFormat)

local LocalPlayer = Players.LocalPlayer

local OPTION_NAMES = { "FirstOption", "SecondOption", "ThirdOption" }

local PlusPercentShrinkController = {}

function PlusPercentShrinkController.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local feature = playerGui:WaitForChild("Main"):WaitForChild("Stats"):WaitForChild("PlusPercentShrink")
	local playerData = LocalPlayer:WaitForChild("PlayerData")
	local shrinkValue = playerData:WaitForChild("Shrink")

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
				Net:RemoteEvent("RequestPlusPercentShrink"):FireServer(optionName)
			end)
		end
	end

	local function refreshPreviews()
		local currentShrink = shrinkValue.Value
		for optionName, tierLabel in tierLabels do
			local percent = PlusPercentShrinkConfig[optionName]
			if percent then
				local bonus = math.floor(currentShrink * percent)
				tierLabel.Text = `+{NumberFormat.Format(bonus)} Shrink`
			end
		end
	end

	shrinkValue:GetPropertyChangedSignal("Value"):Connect(refreshPreviews)
	refreshPreviews()
end

return PlusPercentShrinkController
