--//Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Pacakges
local RemoteConfig = require(ReplicatedStorage.Shared.Configs.RemoteConfig)
local Net = require(ReplicatedStorage.Shared.Packages.Net)

--//Controllers
local PopUpController = nil
--//Cache
local localPlayer = nil
local WorldTeleportFrame = nil

local TeleportWorldsController = {}

local function RequestTeleportToWorld(worldNum: number)
	Net:RemoteEvent(RemoteConfig.Teleport.RequestTeleportToWorld.Name):FireServer(worldNum)
	PopUpController.Close(WorldTeleportFrame)
end

local function SetupTeleportWorldFrame()
	for _, worldFrame in WorldTeleportFrame:WaitForChild("ScrollingFrame"):GetChildren() do
		local worldNum = tonumber(worldFrame.Name)
		if not worldNum then
			continue
		end
		worldFrame:WaitForChild("Teleport"):WaitForChild("TextButton").Activated:Connect(function()
			RequestTeleportToWorld(worldNum)
		end)
	end
end

local function RefreshTeleportWorldFrame(currentWorld)
	for _, worldFrame in WorldTeleportFrame:WaitForChild("ScrollingFrame"):GetChildren() do
		local worldNum = tonumber(worldFrame.Name)
		if not worldNum then
			continue
		end
		local alreadyInWorld = worldNum == localPlayer:WaitForChild("PlayerData"):WaitForChild("World").Value
        worldFrame:WaitForChild("Teleport"):WaitForChild("TextButton"):WaitForChild("TextLabel").Text = alreadyInWorld and "You're here" or "Teleport"
	end
end

function TeleportWorldsController.Start(Controllers)
	localPlayer = Players.LocalPlayer
	WorldTeleportFrame = localPlayer:WaitForChild("PlayerGui"):WaitForChild("Main"):WaitForChild("WorldTeleport")

	PopUpController = Controllers.PopupController
	SetupTeleportWorldFrame()

    RefreshTeleportWorldFrame()
    localPlayer:WaitForChild("PlayerData"):WaitForChild("World").Changed:Connect(RefreshTeleportWorldFrame)
end

return TeleportWorldsController
