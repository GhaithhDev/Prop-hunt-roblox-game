local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local TeleportConfig = require(ReplicatedStorage.Shared.Configs.TeleportConfig)

local LocalPlayer = Players.LocalPlayer

local WinsTeleportController = {}

function WinsTeleportController.Start()
	Net:Connect("WinAwarded", function()
		local character = LocalPlayer.Character
		if not character then return end

		local playerData = LocalPlayer:WaitForChild("PlayerData")
		local currentWorld = playerData:WaitForChild("World").Value

		local position = TeleportConfig.WorldTeleportPositions[currentWorld]
		if not position then return end

		character:PivotTo(CFrame.new(position))
	end)
end

return WinsTeleportController
