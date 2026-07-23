local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local TeleportConfig = require(ReplicatedStorage.Shared.Configs.TeleportConfig)

local LocalPlayer = Players.LocalPlayer

-- Only World 1 exists so far - revisit once there's a way to know which world
-- a player is currently in.
local CURRENT_WORLD = 1

local WinsTeleportController = {}

function WinsTeleportController.Start()
	Net:Connect("WinAwarded", function()
		local character = LocalPlayer.Character
		if not character then return end

		local position = TeleportConfig.WorldTeleportPositions[CURRENT_WORLD]
		if not position then return end

		character:PivotTo(CFrame.new(position))
	end)
end

return WinsTeleportController
