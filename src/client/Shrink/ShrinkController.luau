local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShrinkConfig = require(ReplicatedStorage.Shared.Configs.ShrinkConfig)
local Net = require(ReplicatedStorage.Shared.Packages.Net)

local TRAIL_ASSETS = ReplicatedStorage.Shared.Assets.Trails

local LocalPlayer = Players.LocalPlayer

local ShrinkController = {}

local function GetMinScale(levelValue)
	return ShrinkConfig.GetScaleForLevel(levelValue.Value)
end

-- Every client runs this identically for every player (not just LocalPlayer),
-- driven only by that player's own replicated PlayerData.Level and CustomScale
-- attribute - so everyone converges on the same scale for the same player
-- independently, without the server ever calling ScaleTo itself.
local function rescaleTrail(player: Player, character: Model, scale: number)
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	local attachment0 = humanoidRootPart:FindFirstChild("Attachment0")
	local attachment1 = humanoidRootPart:FindFirstChild("Attachment1")
	local trailEffect = humanoidRootPart:FindFirstChild("TrailEffect")
	if not (attachment0 and attachment1 and trailEffect) then return end

	local playerData = player:FindFirstChild("PlayerData")
	local equippedTrailValue = playerData and playerData:FindFirstChild("EquippedTrail")
	local equippedTrail = equippedTrailValue and equippedTrailValue.Value
	if not equippedTrail or equippedTrail == "" then return end

	-- The template is never mutated (only :Clone()'d by InventoryService), so
	-- it's always safe to read as the "scale 1.0" baseline, however many times
	-- this rescale runs later.
	local template = TRAIL_ASSETS:FindFirstChild(equippedTrail)
	if not template then return end

	local baseAttachment0 = template:FindFirstChild("Attachment0")
	local baseAttachment1 = template:FindFirstChild("Attachment1")
	local baseTrailEffect = template:FindFirstChild("TrailEffect")
	if not (baseAttachment0 and baseAttachment1 and baseTrailEffect) then return end

	attachment0.Position = baseAttachment0.Position * scale
	attachment1.Position = baseAttachment1.Position * scale
	trailEffect.Lifetime = baseTrailEffect.Lifetime * scale
	trailEffect.MinLength = baseTrailEffect.MinLength * scale
	trailEffect.MaxLength = baseTrailEffect.MaxLength * scale
end

local function applyScaleAndTrail(player: Player, character: Model, level: number, customScale: number?)
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

	rescaleTrail(player, character, scale)
end

local function setupPlayerScaling(player: Player)
	local playerData = player:WaitForChild("PlayerData")
	local levelValue = playerData:WaitForChild("Level")
	local equippedTrailValue = playerData:WaitForChild("EquippedTrail")

	local function refresh()
		local character = player.Character
		if character then
			local customScale = player:GetAttribute("CustomScale") :: number?
			applyScaleAndTrail(player, character, levelValue.Value, customScale)
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
end

return ShrinkController
