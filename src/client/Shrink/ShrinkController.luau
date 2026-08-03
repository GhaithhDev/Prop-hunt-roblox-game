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

local LocalPlayer = Players.LocalPlayer

local ShrinkController = {}

local function GetMinScale(levelValue)
	return ShrinkConfig.GetScaleForLevel(levelValue.Value)
end

local function applyEquippedEffects(player: Player)
	local character = player.Character
	local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	local playerData = player:WaitForChild("PlayerData")

	for _, name in TRAIL_PART_NAMES do
		local existing = humanoidRootPart:FindFirstChild(name)
		if existing then existing:Destroy() end
	end
	local existingAura = humanoidRootPart:FindFirstChild(AURA_PART_NAME)
	if existingAura then existingAura:Destroy() end

	
	local equippedTrail = playerData:WaitForChild("EquippedTrail").Value
	if equippedTrail ~= "" then
		local template = TRAIL_ASSETS:FindFirstChild(equippedTrail)
		if template then
			local clone = template:Clone()
			for _, part in clone:GetChildren() do
				part.Parent = humanoidRootPart
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

			local boundingCFrame, boundingSize = character:GetBoundingBox()
			clone.CFrame = boundingCFrame
			clone.Size = boundingSize
			clone.Parent = humanoidRootPart

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = humanoidRootPart
			weld.Part1 = clone
			weld.Parent = clone
		end
	end
end

local function applyScaleAndEffects(player: Player, character: Model, level: number, customScale: number?)
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
	local scale = ShrinkConfig.GetEffectiveScale(level, customScale)

	-- ScaleTo re-derives WalkSpeed/JumpPower/JumpHeight from the model's new
	-- size as a side effect, clobbering whatever Trail-based speed the server
	-- applied - save and restore them around the call.
	local walkSpeed = humanoid.WalkSpeed
	local jumpPower = humanoid.JumpPower
	local jumpHeight = humanoid.JumpHeight
	character:ScaleTo(scale)
	humanoid.WalkSpeed = walkSpeed
	humanoid.JumpPower = jumpPower
	humanoid.JumpHeight = jumpHeight
	character:SetAttribute("CurrentScale", scale)

	applyEquippedEffects(player)
end

local function setupPlayerScaling(player: Player)
	local playerData = player:FindFirstChild("PlayerData")
	local levelValue = playerData and playerData:FindFirstChild("Level")
	local equippedTrailValue = playerData:WaitForChild("EquippedTrail")
	if not playerData then
		warn(`Player {player.Name} doesn't have data yet, won't apply scale and effects yet`)
		failedToApplyScalePlayers[player] = true
		return 
	end
	failedToApplyScalePlayers[player] = nil

	
	

	local function refresh()
		local character = player.Character
		if character then
			local customScale = player:GetAttribute("CustomScale") :: number?
			applyScaleAndEffects(player, character, levelValue.Value, customScale)
		end
	end

	levelValue:GetPropertyChangedSignal("Value"):Connect(refresh)
	equippedTrailValue:GetPropertyChangedSignal("Value"):Connect(refresh)
	player:GetAttributeChangedSignal("CustomScale"):Connect(refresh)
	player.CharacterAdded:Connect(refresh)

	if player.Character then
		refresh()
	end
end

local function HookCurrentScaleDisplay(character, currentScaleLabel, scaleInput)
	local function UpdateCurrentScaleLabel()
		local scale = character:GetAttribute("CurrentScale") or ShrinkConfig.BaseScale
		currentScaleLabel.Text = "current scale: " .. scale
		scaleInput.PlaceholderText = tostring(scale)
	end

	character:GetAttributeChangedSignal("CurrentScale"):Connect(UpdateCurrentScaleLabel)
	UpdateCurrentScaleLabel()
end

local function LookForUnHookedPlayers()
	task.wait(1)
	for player , isUnHooked in pairs(failedToApplyScalePlayers) do
		if not isUnHooked then return end 
		warn(`Hooking scale / trails connection for playe: {player.Name} whoose his data wasn't loaded yet`)
		setupPlayerScaling(player)
	end
end

function ShrinkController.Start()
	-- Scale + Trail sizing for every player (LocalPlayer included, same code
	-- path, no special-casing).
	for _, player in Players:GetPlayers() do
		setupPlayerScaling(player)
	end
	Players.PlayerAdded:Connect(setupPlayerScaling)

	-- ShrinkSettings manual-resize panel - inherently LocalPlayer-only UI.
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local shrinkSettings = playerGui:WaitForChild("Main"):WaitForChild("RightIcons")
	:WaitForChild("ShrinkSettings")
	local minScaleLabel = shrinkSettings:WaitForChild("MinScaleLabel")
	local scaleInput = shrinkSettings:WaitForChild("ScaleInput")
	local currentScaleLabel = shrinkSettings:WaitForChild("CurrentScale")
	local applyButton = shrinkSettings:WaitForChild("Apply")

	local playerData = LocalPlayer:WaitForChild("PlayerData")
	local levelValue = playerData:WaitForChild("Level")

	local function UpdateMinScaleLabel()
		minScaleLabel.Text = "Min Scale: " .. GetMinScale(levelValue)
	end

	levelValue:GetPropertyChangedSignal("Value"):Connect(UpdateMinScaleLabel)
	UpdateMinScaleLabel()

	LocalPlayer.CharacterAdded:Connect(function(character)
		HookCurrentScaleDisplay(character, currentScaleLabel, scaleInput)
	end)
	if LocalPlayer.Character then
		HookCurrentScaleDisplay(LocalPlayer.Character, currentScaleLabel, scaleInput)
	end

	applyButton.Activated:Connect(function()
		local desiredScale = tonumber(scaleInput.Text)
		local minScale = GetMinScale(levelValue)

		if not desiredScale or desiredScale ~= desiredScale then
			warn(`ShrinkController: "{scaleInput.Text}" is not a valid number`)
			return
		end

		if desiredScale < minScale or desiredScale > ShrinkConfig.BaseScale then
			warn(`ShrinkController: {desiredScale} is outside the allowed range {minScale}-{ShrinkConfig.BaseScale}`)
			return
		end

		Net:RemoteEvent("SetCustomSize"):FireServer(desiredScale)
	end)

	task.spawn(LookForUnHookedPlayers)

end

return ShrinkController
