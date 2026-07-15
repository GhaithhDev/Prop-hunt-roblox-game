local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NumberFormat = require(ReplicatedStorage.Shared.Packages.NumberFormat)
local RebirthConfig = require(ReplicatedStorage.Shared.Configs.RebirthConfig)

local LocalPlayer = Players.LocalPlayer

local RebirthMultiplierController = {}

function RebirthMultiplierController.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local label = playerGui:WaitForChild("Main"):WaitForChild("Stats"):WaitForChild("UpperContainer"):WaitForChild("Multiplayer"):WaitForChild("RebirthMultiplayer")

	local playerData = LocalPlayer:WaitForChild("PlayerData")
	local rebirthsValue = playerData:WaitForChild("Rebirths")

	local function update()
		local multiplier = RebirthConfig.GetMultiplierForRebirths(rebirthsValue.Value)
		label.Text = `Multiplier  x{NumberFormat.FormatDecimal(multiplier)}  (Rebirth)`
	end

	rebirthsValue:GetPropertyChangedSignal("Value"):Connect(update)

	update()
end

return RebirthMultiplierController
