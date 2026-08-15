--!nocheck
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WeaponConstants = require(ReplicatedStorage.Shared.Configs.WeaponConstants)
local Trove = require(ReplicatedStorage.Shared.Packages.Trove)
local lerp = require(ReplicatedStorage.Shared.Weapon.Utility.lerp)
local getAudioTarget = require(ReplicatedStorage.Shared.Weapon.Utility.getAudioTarget)
local bindSoundsToAnimationEvents = require(ReplicatedStorage.Shared.Weapon.Utility.bindSoundsToAnimationEvents)

local camera = Workspace.CurrentCamera
local viewModels = ReplicatedStorage.Shared.Weapon.ViewModels

local ViewModelController = {}
ViewModelController.__index = ViewModelController

function ViewModelController.new(gun: Tool)
	local handle = gun:WaitForChild("Handle")
	local sounds = gun:FindFirstChild("Sounds")

	local viewModelName = gun:GetAttribute(WeaponConstants.VIEW_MODEL_ATTRIBUTE)
	local viewModelTemplate = viewModelName and viewModels:FindFirstChild(viewModelName)
	assert(
		viewModelTemplate,
		`Gun "{gun.Name}" is missing a viewmodel - set its {WeaponConstants.VIEW_MODEL_ATTRIBUTE} attribute to a Model under ReplicatedStorage.Shared.Weapon.ViewModels`
	)

	local viewModel = viewModelTemplate:Clone()
	local muzzle = viewModel:FindFirstChild("MuzzleAttachment", true)
	assert(muzzle, `{viewModel.Name} viewmodel is missing a MuzzleAttachment!`)

	local animator = viewModel.AnimationController.Animator
	local animationsFolder = viewModel.Animations
	local audioTarget = getAudioTarget("World", handle)

	-- The viewModel needs to be parented to the DataModel in order to load animations, otherwise it will throw an error
	viewModel.Parent = ReplicatedStorage

	local animations = {}
	for _, animation in animationsFolder:GetChildren() do
		local animationTrack = animator:LoadAnimation(animation)
		animations[animation.Name] = animationTrack

		-- Sounds will all be driven by animation events
		bindSoundsToAnimationEvents(animationTrack, sounds, audioTarget)
	end

	local self = {
		enabled = false,
		gun = gun,
		handle = handle,
		model = viewModel,
		muzzle = muzzle,
		animations = animations,
		toolInstances = {},
		trove = Trove.new(),
		stride = 0,
		bobbing = 0,
	}
	setmetatable(self, ViewModelController)

	return self
end

function ViewModelController:update(deltaTime: number)
	-- Hide tool instances
	for _, instance in self.toolInstances do
		instance.LocalTransparencyModifier = 1
	end

	-- View model bobbing animation
	local moveSpeed = (self.handle.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
	local bobbingSpeed = moveSpeed * WeaponConstants.VIEW_MODEL_BOBBING_SPEED
	local bobbing = math.min(bobbingSpeed, 1)

	self.stride = (self.stride + bobbingSpeed * deltaTime) % (math.pi * 2)
	self.bobbing = lerp(self.bobbing, bobbing, math.min(deltaTime * WeaponConstants.VIEW_MODEL_BOBBING_TRANSITION_SPEED, 1))

	local x = math.sin(self.stride)
	local y = math.sin(self.stride * 2)
	local bobbingOffset = Vector3.new(x, y, 0) * WeaponConstants.VIEW_MODEL_BOBBING_AMOUNT * self.bobbing
	local bobbingCFrame = CFrame.new(bobbingOffset)

	self.model:PivotTo(camera.CFrame * WeaponConstants.VIEW_MODEL_OFFSET * bobbingCFrame)
end

function ViewModelController:checkForToolInstance(instance: Instance)
	if not (instance:IsA("BasePart") or instance:IsA("Decal")) then
		return
	end

	local tool = instance:FindFirstAncestorOfClass("Tool")
	if not tool then
		return
	end

	table.insert(self.toolInstances, instance)
end

function ViewModelController:hideToolInstances()
	local character = self.gun.Parent

	self.trove:Connect(character.DescendantAdded, function(descendant: Instance)
		self:checkForToolInstance(descendant)
	end)

	self.trove:Connect(character.DescendantRemoving, function(descendant: Instance)
		local index = table.find(self.toolInstances, descendant)
		if index then
			table.remove(self.toolInstances, index)
		end
	end)

	for _, descendant in character:GetDescendants() do
		self:checkForToolInstance(descendant)
	end
end

function ViewModelController:stopHidingToolInstances()
	table.clear(self.toolInstances)
	self.trove:Clean()
end

function ViewModelController:getMuzzlePosition(): Vector3
	return self.muzzle.WorldPosition
end

function ViewModelController:playShootAnimation()
	if self.animations.Shoot then
		self.animations.Shoot:Play(0)
	end
	self.muzzle.FlashEmitter:Emit(1)
	self.muzzle.CircleEmitter:Emit(1)
end

function ViewModelController:playReloadAnimation(reloadTime: number)
	if self.animations.Shoot then
		self.animations.Shoot:Stop()
	end
	if self.animations.Reload then
		local speed = self.animations.Reload.Length / reloadTime
		self.animations.Reload:Play(WeaponConstants.VIEW_MODEL_RELOAD_FADE_TIME, 1, speed)
	end
end

function ViewModelController:enable()
	if self.enabled then
		return
	end
	self.enabled = true

	self.trove:BindToRenderStep(
		WeaponConstants.VIEW_MODEL_BIND_NAME,
		Enum.RenderPriority.Camera.Value + 2, -- after aim assist
		function(deltaTime: number)
			self:update(deltaTime)
		end
	)
	self.model.Parent = Workspace
	self:hideToolInstances()

	-- Play equip and idle animations
	if self.animations.Idle then
		self.animations.Idle:Play()
	end
	if self.animations.Equip then
		self.animations.Equip:Play(0)
	end
end

function ViewModelController:disable()
	if not self.enabled then
		return
	end
	self.enabled = false

	self.model.Parent = nil
	self:stopHidingToolInstances()

	for _, animation in self.animations do
		animation:Stop(0)
	end
end

function ViewModelController:destroy()
	self:disable()
	self.trove:Destroy()
	self.model:Destroy()
end

return ViewModelController
