local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Packages.Net)

local LocalPlayer = Players.LocalPlayer

local TreadmillController = {}

function TreadmillController.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local spawnButton = playerGui:WaitForChild("Main"):WaitForChild("LeftIcons"):WaitForChild("SpawnTreadmil")

	spawnButton.Activated:Connect(function()
		Net:RemoteEvent("ToggleSpawn"):FireServer()
	end)
end

return TreadmillController
