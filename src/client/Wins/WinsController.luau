local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NumberFormat = require(ReplicatedStorage.Shared.Packages.NumberFormat)

local LocalPlayer = Players.LocalPlayer

local WinsController = {}

function WinsController.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local textLabel = playerGui:WaitForChild("Main"):WaitForChild("WinsCounter"):WaitForChild("TextLabel")

	local playerData = LocalPlayer:WaitForChild("PlayerData")
	local winsValue = playerData:WaitForChild("Wins")

	local function UpdateText()
		textLabel.Text = NumberFormat.Format(winsValue.Value)
	end

	winsValue:GetPropertyChangedSignal("Value"):Connect(UpdateText)
	UpdateText()
end

return WinsController
