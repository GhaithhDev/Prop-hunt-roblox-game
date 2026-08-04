local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShrinkConfig = require(ReplicatedStorage.Shared.Configs.ShrinkConfig)
local Net = require(ReplicatedStorage.Shared.Packages.Net)

local TRAIL_ASSETS = ReplicatedStorage.Shared.Assets.Trails
local AURA_ASSETS = ReplicatedStorage.Shared.Assets.Auras

-- Every Trail template's Folder contains children with these exact fixed
-- names (only Color/etc differ per trail) - lets cleanup find and remove
-- whichever trail is currently equipped without needing to track which one.
local TRAIL_PART_NAMES = { "Attachment0", "Attachment1", "TrailEffect" }
local AURA_PART_NAME = "AuraEffect"

local failedToApplyScalePlayers = {}
local madeDataConnections = {}

local ShrinkController = {}


local function applyEquippedEffects(player: Player, boundingCFrame: CFrame, boundingSize: Vector3)
	local character = player.Character
	local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")

	local playerData = player:WaitForChild("PlayerData")

	for _, name in TRAIL_PART_NAMES do
		local existing = humanoidRootPart:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end
	local existingAura = humanoidRootPart:FindFirstChild(AURA_PART_NAME)
	if existingAura then
		existingAura:Destroy()
	end

	local equippedTrail = playerData:WaitForChild("EquippedTrail").Value
	if equippedTrail ~= "" then
		local template = TRAIL_ASSETS:FindFirstChild(equippedTrail)
		if template then
			local clone = template:Clone()
			for _, part in clone:GetChildren() do
				part.Parent = humanoidRootPart
				if part:IsA("Trail") then
					part.FaceCamera = true
				elseif part.Name == "Attachment0" then
					part.Position = Vector3.new(0, boundingSize.X / 4, 0)
				elseif part.Name == "Attachment1" then
					part.Position = Vector3.new(0, -boundingSize.X / 4, 0)
				end
			end
			clone:Destroy()
		end
	end

	local equippedAura = playerData:WaitForChild("EquippedAura").Value
	if equippedAura ~= "" then
		local template = AURA_ASSETS:FindFirstChild(equippedAura)
		if template then
			local clone = template:Clone()
			clone.Name = AURA_PART_NAME

			clone.CFrame = boundingCFrame
			clone.Size = boundingSize / 1.5
			clone.Parent = humanoidRootPart

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = humanoidRootPart
			weld.Part1 = clone
			weld.Parent = clone
		end
	end
end

local function applyScaleAndEffects(player: Player, character: Model, level: number, customScale: number?, world: number?)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	local scale = ShrinkConfig.GetEffectiveScale(level, customScale, world)
	local previousScale = (character:GetAttribute("CurrentScale") :: number?) or ShrinkConfig.BaseScale

	
	local ratio = scale / previousScale
	local boundingCFrame, boundingSize = character:GetBoundingBox()
	local localOffset = rootPart.CFrame:ToObjectSpace(boundingCFrame)
	local predictedBoundingCFrame = rootPart.CFrame * CFrame.new(localOffset.Position * ratio)
	local predictedBoundingSize = boundingSize * ratio

	local walkSpeed = humanoid.WalkSpeed
	local jumpPower = humanoid.JumpPower
	local jumpHeight = humanoid.JumpHeight
	character:ScaleTo(scale)
	humanoid.WalkSpeed = walkSpeed
	humanoid.JumpPower = jumpPower
	humanoid.JumpHeight = jumpHeight
	character:SetAttribute("CurrentScale", scale)

	applyEquippedEffects(player, predictedBoundingCFrame, predictedBoundingSize)
end

local function OnCharacterAdded(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChild("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local playerData = player:FindFirstChild("PlayerData")
	local levelValue = playerData and playerData:FindFirstChild("Level")
	local equippedTrailValue = playerData and playerData:FindFirstChild("EquippedTrail")
	local equippedAuraValue = playerData and playerData:FindFirstChild("EquippedAura")
	local worldValue = playerData and playerData:FindFirstChild("World")

	local isDataReady = playerData and levelValue and equippedTrailValue and equippedAuraValue and worldValue
	local isCharacterReady = humanoid and root

	if not isDataReady or not isCharacterReady then
		warn(
			`Player {player.Name} doesn't have data or his character isn't loaded yet, won't apply scale and effects yet`
		)
		failedToApplyScalePlayers[player] = true
		return
	end

	local function refresh()
		local customScale = player:GetAttribute("CustomScale") :: number?
		applyScaleAndEffects(player, character, levelValue.Value, customScale, worldValue.Value)
		print("applied scale and effects for " .. player.Name)
	end

	local function MakeDataConnections(levelValue, equippedTrailValue, equippedAuraValue, worldValue)
		levelValue:GetPropertyChangedSignal("Value"):Connect(function()
			OnCharacterAdded(player)
		end)
		equippedTrailValue:GetPropertyChangedSignal("Value"):Connect(function()
			OnCharacterAdded(player)
		end)
		equippedAuraValue:GetPropertyChangedSignal("Value"):Connect(function()
			OnCharacterAdded(player)
		end)
		worldValue:GetPropertyChangedSignal("Value"):Connect(function()
			OnCharacterAdded(player)
		end)

		player:GetAttributeChangedSignal("CustomScale"):Connect(function()
			OnCharacterAdded(player)
		end)

		madeDataConnections[player] = true
		print("Made data connections for " .. player.Name)
	end

	if not madeDataConnections[player] then
		MakeDataConnections(levelValue, equippedTrailValue, equippedAuraValue, worldValue)
	end

	refresh()
end

local function LookForUnHookedPlayers()
	while task.wait(1) do
		for player, isUnHooked in pairs(failedToApplyScalePlayers) do
			if not isUnHooked then
				return
			end
			warn(
				`Hooking scale / trails connection for playe: {player.Name} whoose data or his character wasn't loaded at character add time`
			)
			failedToApplyScalePlayers[player] = nil
			OnCharacterAdded(player)
		end
	end
end

local function OnPlayerAdded(player: Player)
	if player.Character then
		OnCharacterAdded(player)
	end
	player.CharacterAdded:Connect(function(character: Model)
		OnCharacterAdded(player)
	end)
end

function ShrinkController.Start()
	for _, player in Players:GetPlayers() do
		OnPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(OnPlayerAdded)

	task.spawn(LookForUnHookedPlayers)
end

return ShrinkController
