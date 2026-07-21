local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NumberFormat = require(ReplicatedStorage.Shared.Packages.NumberFormat)

local LocalPlayer = Players.LocalPlayer

local ShrinkPassMultiplierController = {}

function ShrinkPassMultiplierController.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local label = playerGui:WaitForChild("Main"):WaitForChild("Stats"):WaitForChild("UpperContainer"):WaitForChild("LeftMultiplayer"):WaitForChild("Gamepass Multiplier")

	local playerData = LocalPlayer:WaitForChild("PlayerData")
	local shrinkPassMultiplierValue = playerData:WaitForChild("ShrinkPassMultiplier")

	local function update()
		label.Text = `Multiplier  x{NumberFormat.FormatDecimal(shrinkPassMultiplierValue.Value)}  (Gamepass)`
	end

	shrinkPassMultiplierValue:GetPropertyChangedSignal("Value"):Connect(update)

	update()
end

return ShrinkPassMultiplierController
