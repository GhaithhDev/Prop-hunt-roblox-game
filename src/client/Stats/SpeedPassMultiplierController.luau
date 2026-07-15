local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NumberFormat = require(ReplicatedStorage.Shared.Packages.NumberFormat)

local LocalPlayer = Players.LocalPlayer

local SpeedPassMultiplierController = {}

function SpeedPassMultiplierController.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local label = playerGui:WaitForChild("Main"):WaitForChild("Stats"):WaitForChild("UpperContainer"):WaitForChild("LeftMultiplayer"):WaitForChild("Gamepass Multiplier")

	local playerData = LocalPlayer:WaitForChild("PlayerData")
	local speedPassMultiplierValue = playerData:WaitForChild("SpeedPassMultiplier")

	local function update()
		label.Text = `Multiplier  x{NumberFormat.FormatDecimal(speedPassMultiplierValue.Value)}  (Gamepass)`
	end

	speedPassMultiplierValue:GetPropertyChangedSignal("Value"):Connect(update)

	update()
end

return SpeedPassMultiplierController
