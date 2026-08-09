--//Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

--//Pacakges
local Trove = require(ReplicatedStorage.Shared.Packages.Trove)

--//CONFIGS
local TEST_MODE = false
local CLASSIC_ZOOM_KICK_DISTANCE = 10
local CLASSIC_ZOOM_KICK_DURATION = 0.1

--//Cache
local ToggleFirstPersonController = {}
local player = Players.LocalPlayer
local characterConnectoins = nil

local function ClearCharacterConnections()
	if characterConnectoins then
		characterConnectoins:Destroy()
	end
end

local function OnToolAdded(tool: Instance)
	if tool:GetAttribute("ForceFirstPerson") then
		ToggleFirstPersonController.ToggleFirstPerson()
	end
end

local function OnToolRemoved(tool: Instance)
	if tool:GetAttribute("ForceFirstPerson") then
		ToggleFirstPersonController.ToggleFirstPerson()
	end
end

local function OnCharacterAdded(character: Model)
	ClearCharacterConnections()
	characterConnectoins = Trove.new()
	characterConnectoins:Add(character.ChildAdded:Connect(OnToolAdded))
	characterConnectoins:Add(character.ChildRemoved:Connect(OnToolRemoved))
end

local function kickZoomOut()
	local originalMinZoomDistance = player.CameraMinZoomDistance
	player.CameraMinZoomDistance = CLASSIC_ZOOM_KICK_DISTANCE
	task.delay(CLASSIC_ZOOM_KICK_DURATION, function()
		player.CameraMinZoomDistance = originalMinZoomDistance
	end)
end

function ToggleFirstPersonController.ToggleFirstPerson()
	if player.CameraMode == Enum.CameraMode.LockFirstPerson then
		player.CameraMode = Enum.CameraMode.Classic
		kickZoomOut()
	else
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	end
end

local function TestFeatures()
	UserInputService.InputBegan:Connect(function(a0: InputObject, a1: boolean)
		if a0.KeyCode ~= Enum.KeyCode.T then
			return
		end

		ToggleFirstPersonController.ToggleFirstPerson()
	end)
end

function ToggleFirstPersonController.Start()
	if player.Character then
		OnCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(OnCharacterAdded)

	if TEST_MODE then
		TestFeatures()
	end
end

return ToggleFirstPersonController
