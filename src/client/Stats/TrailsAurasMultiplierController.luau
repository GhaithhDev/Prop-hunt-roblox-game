local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrailsConfig = require(ReplicatedStorage.Shared.Configs.TrailsConfig)
local AurasConfig = require(ReplicatedStorage.Shared.Configs.AurasConfig)

local LocalPlayer = Players.LocalPlayer

local TrailsAurasMultiplierController = {}

function TrailsAurasMultiplierController.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local label = playerGui:WaitForChild("Main"):WaitForChild("Stats"):WaitForChild("Multiplayer"):WaitForChild("Trails+AurasMultiplayer")

	local playerData = LocalPlayer:WaitForChild("PlayerData")
	local trailValue = playerData:WaitForChild("EquippedTrail")
	local auraValue = playerData:WaitForChild("EquippedAura")

	local function update()
		local multiplier = TrailsConfig.GetMultiplierForEquipped(trailValue.Value) * AurasConfig.GetMultiplierForEquipped(auraValue.Value)
		label.Text = `{multiplier}x`
	end

	trailValue:GetPropertyChangedSignal("Value"):Connect(update)
	auraValue:GetPropertyChangedSignal("Value"):Connect(update)

	update()
end

return TrailsAurasMultiplierController
