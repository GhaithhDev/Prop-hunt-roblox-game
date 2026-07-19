local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Net = require(ReplicatedStorage.Shared.Packages.Net)
local SoundUtils = require(ReplicatedStorage.Shared.Packages.SoundUtils)

local LowGravityController = {}

function LowGravityController.Start()
	Net:Connect("SetGravity", function(gravity: number, playSound: boolean)
		if playSound then
			SoundUtils.PlayLocalSound(SoundService.SFX.Sparkle)
		end
		workspace.Gravity = gravity
	end)
end

return LowGravityController
