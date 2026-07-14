--[[
	SpinController

	Generic decorative spin: any instance tagged with SpinConfig.TAG_NAME rotates
	around its own Y axis at the rate (degrees/sec) read from its
	SpinConfig.SPEED_ATTRIBUTE attribute. Any service can opt an instance into
	spinning just by tagging it and setting that attribute — no per-feature spin
	code needed.
]]

--//Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

--//Configs
local SpinConfig = require(ReplicatedStorage.Shared.Configs.SpinConfig)

local SpinController = {}

local function spin(instance: Instance, dt: number)
	local speed = instance:GetAttribute(SpinConfig.SPEED_ATTRIBUTE)
	if typeof(speed) ~= "number" or speed == 0 then
		return
	end

	local axis = instance:GetAttribute(SpinConfig.AXIS_ATTRIBUTE)
	local delta =  CFrame.Angles(
		axis == "X" and math.rad(speed) * dt or 0,
		axis == "Y" and math.rad(speed) * dt or 0,
		axis == "Z" and math.rad(speed) * dt or 0
	)

	if instance:IsA("Model") then
		instance:PivotTo(instance:GetPivot() * delta)
	elseif instance:IsA("BasePart") then
		instance.CFrame = instance.CFrame * delta
	end
end

function SpinController.Start()
	RunService.RenderStepped:Connect(function(dt)
		for _, instance in CollectionService:GetTagged(SpinConfig.TAG_NAME) do
			spin(instance, dt)
		end
	end)
end

return SpinController
