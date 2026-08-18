--!nocheck
--[[
	GunController

	Per-tool client controller for a gun: equip/unequip, activate/deactivate,
	shoot/reload, recoil, and wiring up the ViewModel/CameraRecoiler/
	CharacterAnimation/Gui/TouchInput/AimAssist pieces. Ported from the FPS
	template's BlasterController.

	Instantiate one of these per equipped gun Tool - see
	client/Weapon/GunEquipController.luau, which does this automatically for any
	Tool tagged Tags.Gun.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local WeaponConstants = require(ReplicatedStorage.Shared.Configs.WeaponConstants)
local RemoteConfig = require(ReplicatedStorage.Shared.Configs.RemoteConfig)
local Net = require(ReplicatedStorage.Shared.Packages.Net)
local Trove = require(ReplicatedStorage.Shared.Packages.Trove)
local SoundUtils = require(ReplicatedStorage.Shared.Packages.SoundUtils)
local AimAssist = require(ReplicatedStorage.Shared.Packages.AimAssist)
local AimAssistEnum = require(ReplicatedStorage.Shared.Packages.AimAssist.AimAssistEnum)

local getRayDirections = require(ReplicatedStorage.Shared.Weapon.Utility.getRayDirections)
local drawRayResults = require(ReplicatedStorage.Shared.Weapon.Utility.drawRayResults)
local castRays = require(ReplicatedStorage.Shared.Weapon.Utility.castRays)

local ViewModelController = require(script.Parent.ViewModelController)
local GunHudController = require(script.Parent.GunHudController)
local TouchInputController = require(script.Parent.TouchInputController)
local CharacterAnimationController = require(script.Parent.CharacterAnimationController)
local CameraRecoiler = require(script.Parent.CameraRecoiler)

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local random = Random.new()

local sfxFolder = SoundService:FindFirstChild("SFX")

local function playShootSound(gun: Tool, part: BasePart)
	local soundName = gun:GetAttribute(WeaponConstants.SHOOT_SOUND_ATTRIBUTE)
	local sound = soundName and sfxFolder and sfxFolder:FindFirstChild(soundName)
	if sound then
		SoundUtils.PlayFromPart(sound, part)
	end
end

local GunController = {}
GunController.__index = GunController

function GunController.new(gun: Tool)
	local aimAssistController = AimAssist.new()
	local viewModelController = ViewModelController.new(gun)
	local hudController = GunHudController.new(gun)
	local touchInputController = TouchInputController.new(gun)
	local characterAnimationController = CharacterAnimationController.new(gun)

	local haptics = gun:FindFirstChild("Haptics")

	local self = {
		gun = gun,
		aimAssistController = aimAssistController,
		viewModelController = viewModelController,
		hudController = hudController,
		touchInputController = touchInputController,
		characterAnimationController = characterAnimationController,
		activated = false,
		equipped = false,
		shooting = false,
		ammo = gun:GetAttribute(WeaponConstants.AMMO_ATTRIBUTE) or 0,
		reloading = gun:GetAttribute(WeaponConstants.RELOADING_ATTRIBUTE) or false,
		trove = Trove.new(),
		shootHaptic = haptics and haptics:FindFirstChild("ShootHaptic"),
	}
	setmetatable(self, GunController)

	self:initialize()

	return self
end

function GunController:isHumanoidAlive(): boolean
	return self.humanoid and self.humanoid.Health > 0
end

function GunController:canShoot(): boolean
	return self:isHumanoidAlive() and self.equipped and self.ammo > 0 and not self.reloading
end

function GunController:canReload(): boolean
	local magazineSize = self.gun:GetAttribute(WeaponConstants.MAGAZINE_SIZE_ATTRIBUTE)
	return self:isHumanoidAlive() and self.equipped and self.ammo < magazineSize and not self.reloading
end

function GunController:recoil()
	local recoilMin = self.gun:GetAttribute(WeaponConstants.RECOIL_MIN_ATTRIBUTE)
	local recoilMax = self.gun:GetAttribute(WeaponConstants.RECOIL_MAX_ATTRIBUTE)
	if not recoilMin or not recoilMax then
		return
	end

	local xDif = recoilMax.X - recoilMin.X
	local yDif = recoilMax.Y - recoilMin.Y
	local x = recoilMin.X + random:NextNumber() * xDif
	local y = recoilMin.Y + random:NextNumber() * yDif

	local recoil = Vector2.new(math.rad(-x), math.rad(y))

	CameraRecoiler.recoil(recoil)
end

function GunController:shoot()
	local spread = self.gun:GetAttribute(WeaponConstants.SPREAD_ATTRIBUTE) or 0
	local raysPerShot = self.gun:GetAttribute(WeaponConstants.RAYS_PER_SHOT_ATTRIBUTE) or 1
	local range = self.gun:GetAttribute(WeaponConstants.RANGE_ATTRIBUTE) or 1000
	local rayRadius = self.gun:GetAttribute(WeaponConstants.RAY_RADIUS_ATTRIBUTE) or 0.1

	self.viewModelController:playShootAnimation()
	self.characterAnimationController:playShootAnimation()
	self:recoil()
	playShootSound(self.gun, self.viewModelController.handle)

	self.ammo -= 1

	self.hudController:setAmmo(self.ammo)

	local now = Workspace:GetServerTimeNow()
	local origin = camera.CFrame

	local rayDirections = getRayDirections(origin, raysPerShot, math.rad(spread), now)
	for index, direction in rayDirections do
		rayDirections[index] = direction * range
	end

	local rayResults = castRays(player, origin.Position, rayDirections, rayRadius)

	-- Rather than passing the entire table of rayResults to the server, we'll pass the shot origin and a list of tagged humanoids.
	-- The server will then recalculate the ray directions from the origin and validate the tagged humanoids.
	-- Strings are used for the indices since non-contiguous arrays do not get passed over the network correctly.
	-- (This may be non-contiguous in the case of firing a shotgun, where not all of the rays hit a target)
	local tagged = {}
	local didTag = false
	for index, rayResult in rayResults do
		if rayResult.taggedHumanoid then
			tagged[tostring(index)] = rayResult.taggedHumanoid
			didTag = true
		end
	end

	if didTag then
		self.hudController:showHitmarker()
	end

	Net:RemoteEvent(RemoteConfig.Weapon.Shoot.Name):FireServer(now, self.gun, origin, tagged)

	local muzzlePosition = self.viewModelController:getMuzzlePosition()
	drawRayResults(muzzlePosition, rayResults)

	if self.shootHaptic then
		self.shootHaptic:Play()
	end
end

function GunController:startShooting()
	-- If the player tries to shoot without any ammo, reload instead
	if self.ammo == 0 then
		self:reload()
		return
	end

	if not self:canShoot() then
		return
	end

	if self.shooting then
		return
	end

	local fireMode = self.gun:GetAttribute(WeaponConstants.FIRE_MODE_ATTRIBUTE)
	local rateOfFire = self.gun:GetAttribute(WeaponConstants.RATE_OF_FIRE_ATTRIBUTE)

	if fireMode == WeaponConstants.FIRE_MODE.SEMI then
		self.shooting = true
		self:shoot()
		task.delay(60 / rateOfFire, function()
			self.shooting = false

			if self.ammo == 0 then
				self:reload()
			end
		end)
	elseif fireMode == WeaponConstants.FIRE_MODE.AUTO then
		task.spawn(function()
			self.shooting = true
			while self.activated and self:canShoot() do
				self:shoot()
				task.wait(60 / rateOfFire)
			end
			self.shooting = false

			if self.ammo == 0 then
				self:reload()
			end
		end)
	end
end

function GunController:reload()
	if not self:canReload() then
		return
	end

	local reloadTime = self.gun:GetAttribute(WeaponConstants.RELOAD_TIME_ATTRIBUTE)
	local magazineSize = self.gun:GetAttribute(WeaponConstants.MAGAZINE_SIZE_ATTRIBUTE)

	self.viewModelController:playReloadAnimation(reloadTime)
	self.characterAnimationController:playReloadAnimation(reloadTime)

	self.reloading = true
	self.hudController:setReloading(self.reloading)
	Net:RemoteEvent(RemoteConfig.Weapon.Reload.Name):FireServer(self.gun)

	self.reloadTask = task.delay(reloadTime, function()
		self.ammo = magazineSize
		self.reloading = false
		self.reloadTask = nil
		self.hudController:setAmmo(self.ammo)
		self.hudController:setReloading(self.reloading)
	end)
end

function GunController:activate()
	if self.activated then
		return
	end
	self.activated = true

	self:startShooting()
end

function GunController:deactivate()
	if not self.activated then
		return
	end
	self.activated = false
end

function GunController:equip()
	if self.equipped then
		return
	end
	self.equipped = true

	-- Resync ammo and reloading values
	self.ammo = self.gun:GetAttribute(WeaponConstants.AMMO_ATTRIBUTE)
	self.reloading = self.gun:GetAttribute(WeaponConstants.RELOADING_ATTRIBUTE)

	-- Resync aim assist values
	self.range = self.gun:GetAttribute(WeaponConstants.AIM_ASSIST_RANGE_ATTRIBUTE)
	self.fov = self.gun:GetAttribute(WeaponConstants.AIM_ASSIST_FOV_ATTRIBUTE)
	self.friction = self.gun:GetAttribute(WeaponConstants.AIM_ASSIST_FRICTION_STRENGTH_ATTRIBUTE)
	self.tracking = self.gun:GetAttribute(WeaponConstants.AIM_ASSIST_TRACKING_STRENGTH_ATTRIBUTE)
	self.centering = self.gun:GetAttribute(WeaponConstants.AIM_ASSIST_CENTERING_STRENGTH_ATTRIBUTE)

	-- Set up the Aim Assist Controller
	self.aimAssistController:setSubject(Workspace.CurrentCamera)
	self.aimAssistController:setRange(self.range or 0)
	self.aimAssistController:setFieldOfView(self.fov or 0)
	self.aimAssistController:addTargetTag(WeaponConstants.AIM_ASSIST_TARGET_TAG)
	self.aimAssistController:addPlayerTargets(true, true)
	self.aimAssistController:setMethodStrength(AimAssistEnum.AimAssistMethod.Friction, self.friction or 0)
	self.aimAssistController:setMethodStrength(AimAssistEnum.AimAssistMethod.Tracking, self.tracking or 0)
	self.aimAssistController:setMethodStrength(AimAssistEnum.AimAssistMethod.Centering, self.centering or 0)
	self.aimAssistController:setEasingFunc(
		AimAssistEnum.AimAssistEasingAttribute.Distance,
		function(distance: number): number
			if distance < WeaponConstants.AIM_ASSIST_MIN_RANGE then
				return 0
			else
				return 1
			end
		end
	)
	self.aimAssistController:setDebug(false)

	-- Enable Aim Assist
	self.aimAssistController:enable()

	-- Enable view model
	self.viewModelController:enable()

	-- Enable HUD
	self.hudController:setAmmo(self.ammo)
	self.hudController:setReloading(self.reloading)
	self.hudController:enable()

	-- Enable touch input controller
	self.touchInputController:enable()

	-- Enable character animations
	self.characterAnimationController:enable()

	-- Keep track of the humanoid in the character currently equipping the gun.
	-- We need this to make sure the player can't shoot while dead.
	self.humanoid = self.gun.Parent:FindFirstChildOfClass("Humanoid")
end

function GunController:unequip()
	if not self.equipped then
		return
	end
	self.equipped = false

	-- Force deactivate the gun when unequipping it
	self:deactivate()

	-- If the gun is being reloaded, stop it
	if self.reloadTask then
		task.cancel(self.reloadTask)
		self.reloadTask = nil
	end

	-- Disable Aim Assist debug UI
	self.aimAssistController:setDebug(false)
	-- Disable Aim Assist
	self.aimAssistController:disable()

	-- Disable view model
	self.viewModelController:disable()

	-- Disable HUD
	self.hudController:disable()

	-- Disable touch input controller
	self.touchInputController:disable()

	-- Disable character animations
	self.characterAnimationController:disable()
end

function GunController:initialize()
	self.trove:Connect(self.gun.Equipped, function()
		self:equip()
	end)
	self.trove:Connect(self.gun.Unequipped, function()
		self:unequip()
	end)
	self.trove:Connect(self.gun.Activated, function()
		self:activate()
	end)
	self.trove:Connect(self.gun.Deactivated, function()
		self:deactivate()
	end)

	self.trove:Connect(UserInputService.InputBegan, function(inputObject: InputObject, processed: boolean)
		if processed then
			return
		end

		if
			inputObject.KeyCode == WeaponConstants.KEYBOARD_RELOAD_KEY_CODE
			or inputObject.KeyCode == WeaponConstants.GAMEPAD_RELOAD_KEY_CODE
		then
			self:reload()
		end
	end)

	self.trove:Connect(UserInputService.InputChanged, function(inputObject: InputObject, _)
		if
			inputObject.UserInputType == Enum.UserInputType.Gamepad1
			and (inputObject.KeyCode == Enum.KeyCode.Thumbstick1 or inputObject.KeyCode == Enum.KeyCode.Thumbstick2)
		then
			self.aimAssistController:updateGamepadEligibility(inputObject.KeyCode, inputObject.Position)
		end
	end)

	self.trove:Connect(UserInputService.TouchPan, function()
		self.aimAssistController:updateTouchEligibility()
	end)

	self.touchInputController:setReloadCallback(function()
		self:reload()
	end)
end

function GunController:destroy()
	self:unequip()
	self.trove:Destroy()
	self.aimAssistController:destroy()
	self.viewModelController:destroy()
	self.touchInputController:destroy()
	self.characterAnimationController:destroy()
	self.hudController:destroy()
end

return GunController
