local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShrinkConfig = require(ReplicatedStorage.Shared.Configs.ShrinkConfig)
local Net = require(ReplicatedStorage.Shared.Packages.Net)

local LocalPlayer = Players.LocalPlayer

local ShrinkController = {}

local function GetMinScale(levelValue)
	return ShrinkConfig.GetScaleForLevel(levelValue.Value)
end

-- The client (not the server) applies the actual scale, since it owns its
-- own character's physics simulation - having the server call ScaleTo left
-- movement drifty/floaty instead of stopping instantly on key release, since
-- it fought the client's own prediction for its network-owned character.
-- Server just tells us the level (PlayerData.Level, already replicated) and
-- any manual override (the "CustomScale" attribute on the Player instance,
-- set by ShrinkService when SetCustomSize is accepted).
local function applyScale(character, levelValue)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local minScale = GetMinScale(levelValue)
	local customScale = LocalPlayer:GetAttribute("CustomScale")

	local scale
	if customScale then
		scale = math.clamp(customScale, minScale, ShrinkConfig.BaseScale)
	else
		scale = minScale
	end

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

	local function ApplyScaleToCurrentCharacter()
		if LocalPlayer.Character then
			applyScale(LocalPlayer.Character, levelValue)
		end
	end

	levelValue:GetPropertyChangedSignal("Value"):Connect(function()
		UpdateMinScaleLabel()
		ApplyScaleToCurrentCharacter()
	end)
	UpdateMinScaleLabel()

	LocalPlayer:GetAttributeChangedSignal("CustomScale"):Connect(ApplyScaleToCurrentCharacter)

	LocalPlayer.CharacterAdded:Connect(function(character)
		HookCurrentScaleDisplay(character, currentScaleLabel, scaleInput)
		applyScale(character, levelValue)
	end)
	if LocalPlayer.Character then
		HookCurrentScaleDisplay(LocalPlayer.Character, currentScaleLabel, scaleInput)
		applyScale(LocalPlayer.Character, levelValue)
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
