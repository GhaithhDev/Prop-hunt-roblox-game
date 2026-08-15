--[[
	GunEquipController

	Watches the local character for Tools tagged Tags.Gun and spins up/tears down a
	GunController for each one automatically - this is what lets any gun Tool work
	without needing a LocalScript inside it (unlike the original FPS template, which
	required one per Tool).
]]

--//Services
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--//Configs
local Tags = require(ReplicatedStorage.Shared.Configs.Tags)

--//Packages
local Trove = require(ReplicatedStorage.Shared.Packages.Trove)

--//Weapon
local GunController = require(ReplicatedStorage.Shared.Weapon.Gun.GunController)

local GunEquipController = {}

local player = Players.LocalPlayer
local characterTrove = nil
local activeGuns: { [Tool]: any } = {}

local function onToolAdded(tool: Instance)
	if not CollectionService:HasTag(tool, Tags.Gun) then
		return
	end
	if activeGuns[tool] then
		return
	end

	activeGuns[tool] = GunController.new(tool)
end

local function onToolRemoved(tool: Instance)
	local controller = activeGuns[tool]
	if not controller then
		return
	end
	activeGuns[tool] = nil
	controller:destroy()
end

local function onCharacterAdded(character: Model)
	if characterTrove then
		characterTrove:Destroy()
	end
	characterTrove = Trove.new()

	characterTrove:Connect(character.ChildAdded, onToolAdded)
	characterTrove:Connect(character.ChildRemoved, onToolRemoved)

	for _, child in character:GetChildren() do
		onToolAdded(child)
	end
end

function GunEquipController.Start()
	if player.Character then
		onCharacterAdded(player.Character)
	end
	player.CharacterAdded:Connect(onCharacterAdded)
end

return GunEquipController
