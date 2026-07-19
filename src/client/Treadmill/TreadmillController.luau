local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local SoundService = game:GetService("SoundService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local Tags = require(ReplicatedStorage.Shared.Configs.Tags)
local SoundUtils = require(ReplicatedStorage.Shared.Packages.SoundUtils)

local LocalPlayer = Players.LocalPlayer

local TreadmillController = {}

function TreadmillController.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local spawnButton = playerGui:WaitForChild("Main"):WaitForChild("LeftIcons")
	:WaitForChild("LeftIconsContainer"):WaitForChild("SpawnTreadmil"):WaitForChild("Button")

	spawnButton.Activated:Connect(function()
		Net:RemoteEvent("ToggleSpawn"):FireServer()
	end)

	CollectionService:GetInstanceAddedSignal(Tags.TREADMILL):Connect(function(instance)
		if instance:GetAttribute("OwnerId") == LocalPlayer.UserId then
			SoundUtils.PlayLocalSound(SoundService.SFX.PlacedownTreadmill)
		end
	end)
end

return TreadmillController
