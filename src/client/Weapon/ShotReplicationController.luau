--[[
	ShotReplicationController

	Draws the muzzle flash/laser/impact effects for other players' shots, replicated
	from GunService via the Weapon.ReplicateShot unreliable remote. Ported from the
	FPS template's ShotReplication script.
]]

--//Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--//Configs
local RemoteConfig = require(ReplicatedStorage.Shared.Configs.RemoteConfig)

--//Packages
local Net = require(ReplicatedStorage.Shared.Packages.Net)

--//Weapon utility
local drawRayResults = require(ReplicatedStorage.Shared.Weapon.Utility.drawRayResults)
local playRandomSoundFromSource = require(ReplicatedStorage.Shared.Weapon.Utility.playRandomSoundFromSource)
local getAudioTarget = require(ReplicatedStorage.Shared.Weapon.Utility.getAudioTarget)

local castRays = require(ReplicatedStorage.Shared.Weapon.Utility.castRays)

local ShotReplicationController = {}

local function onReplicateShotEvent(gun: Tool, position: Vector3, rayResults: { castRays.RayResult })
	-- Make sure that the gun is currently streamed in
	if gun and gun:IsDescendantOf(game) then
		local handle = gun:FindFirstChild("Handle")
		local sounds = gun:FindFirstChild("Sounds")
		local muzzle = gun:FindFirstChild("MuzzleAttachment", true)

		-- If the gun has a MuzzleAttachment, we'll use that as the laser starting point, otherwise
		-- default to the gun's pivot position.
		if muzzle then
			position = muzzle.WorldPosition
			local flashEmitter = muzzle:FindFirstChild("FlashEmitter")
			if flashEmitter then
				flashEmitter:Emit(1)
			end
		else
			position = gun:GetPivot().Position
		end

		if sounds then
			local shootSounds = sounds:FindFirstChild("Shoot")
			if shootSounds then
				playRandomSoundFromSource(shootSounds, getAudioTarget("World", handle or gun))
			end
		end
	end

	drawRayResults(position, rayResults)
end

function ShotReplicationController.Start()
	Net:ConnectUnreliable(RemoteConfig.Weapon.ReplicateShot.Name, onReplicateShotEvent)
end

return ShotReplicationController
