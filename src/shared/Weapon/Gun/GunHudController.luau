--!nocheck
--[[
	GunHudController

	Ammo counter + reticle + hitmarker HUD for the currently equipped gun. Same
	external API as the original template's GuiController (setAmmo/setReloading/
	showHitmarker/enable/disable), but the whole GUI tree is built with
	Instance.new in code instead of cloned from pre-made ScreenGui instances, so
	there are no binary UI assets to ship. The visuals here are intentionally plain
	(a generic plus-shaped reticle, a simple ammo readout) - restyle freely, the
	rest of the gun system doesn't depend on how this looks.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local WeaponConstants = require(ReplicatedStorage.Shared.Configs.WeaponConstants)
local Trove = require(ReplicatedStorage.Shared.Packages.Trove)
local InputCategorizer = require(script.Parent.InputCategorizer)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local AMMO_TEXT_FORMAT_STRING = `<font transparency="0.5">%s</font>%s`

local function buildGunHud(gun: Tool): ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GunHud"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false

	local uiScale = Instance.new("UIScale")
	uiScale.Name = "UIScale"
	uiScale.Parent = screenGui

	local frame = Instance.new("Frame")
	frame.Name = "Gun"
	frame.AnchorPoint = Vector2.new(1, 1)
	frame.Position = UDim2.fromScale(1, 1)
	frame.Size = UDim2.fromOffset(220, 60)
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = 0.4
	frame.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.Parent = frame

	local listLayout = Instance.new("UIListLayout")
	listLayout.FillDirection = Enum.FillDirection.Horizontal
	listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	listLayout.Padding = UDim.new(0, 8)
	listLayout.Parent = frame

	local iconLabel = Instance.new("ImageLabel")
	iconLabel.Name = "IconLabel"
	iconLabel.BackgroundTransparency = 1
	iconLabel.Size = UDim2.fromOffset(36, 36)
	iconLabel.Image = gun.TextureId
	iconLabel.Parent = frame

	local ammo = Instance.new("Frame")
	ammo.Name = "Ammo"
	ammo.BackgroundTransparency = 1
	ammo.Size = UDim2.new(1, -44, 1, 0)
	ammo.Parent = frame

	local ammoListLayout = Instance.new("UIListLayout")
	ammoListLayout.FillDirection = Enum.FillDirection.Horizontal
	ammoListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	ammoListLayout.Parent = ammo

	local ammoLabel = Instance.new("TextLabel")
	ammoLabel.Name = "AmmoLabel"
	ammoLabel.BackgroundTransparency = 1
	ammoLabel.Size = UDim2.new(0, 60, 1, 0)
	ammoLabel.Font = Enum.Font.GothamBold
	ammoLabel.TextSize = 24
	ammoLabel.TextColor3 = Color3.new(1, 1, 1)
	ammoLabel.TextXAlignment = Enum.TextXAlignment.Right
	ammoLabel.RichText = true
	ammoLabel.Text = ""
	ammoLabel.Parent = ammo

	local magazineLabel = Instance.new("TextLabel")
	magazineLabel.Name = "MagazineLabel"
	magazineLabel.BackgroundTransparency = 1
	magazineLabel.Size = UDim2.new(0, 60, 1, 0)
	magazineLabel.Font = Enum.Font.Gotham
	magazineLabel.TextSize = 16
	magazineLabel.TextColor3 = Color3.new(0.7, 0.7, 0.7)
	magazineLabel.TextXAlignment = Enum.TextXAlignment.Left
	magazineLabel.Text = ""
	magazineLabel.Parent = ammo

	return screenGui
end

local function buildTick(anchorPoint: Vector2, position: UDim2, size: UDim2): Frame
	local tick = Instance.new("Frame")
	tick.AnchorPoint = anchorPoint
	tick.Position = position
	tick.Size = size
	tick.BackgroundColor3 = Color3.new(1, 1, 1)
	tick.BorderSizePixel = 0
	return tick
end

local function buildReticleGui(): ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GunReticle"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false

	local reticle = Instance.new("Frame")
	reticle.Name = "Reticle"
	reticle.AnchorPoint = Vector2.new(0.5, 0.5)
	reticle.Position = UDim2.fromScale(0.5, 0.5)
	reticle.Size = UDim2.fromOffset(24, 24)
	reticle.BackgroundTransparency = 1
	reticle.Parent = screenGui

	local GAP = 4
	local LENGTH = 8
	local THICKNESS = 2
	buildTick(Vector2.new(0.5, 1), UDim2.new(0.5, 0, 0.5, -GAP), UDim2.fromOffset(THICKNESS, LENGTH)).Parent = reticle
	buildTick(Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0.5, GAP), UDim2.fromOffset(THICKNESS, LENGTH)).Parent = reticle
	buildTick(Vector2.new(1, 0.5), UDim2.new(0.5, -GAP, 0.5, 0), UDim2.fromOffset(LENGTH, THICKNESS)).Parent = reticle
	buildTick(Vector2.new(0, 0.5), UDim2.new(0.5, GAP, 0.5, 0), UDim2.fromOffset(LENGTH, THICKNESS)).Parent = reticle

	local hitmarker = Instance.new("CanvasGroup")
	hitmarker.Name = "Hitmarker"
	hitmarker.AnchorPoint = Vector2.new(0.5, 0.5)
	hitmarker.Position = UDim2.fromScale(0.5, 0.5)
	hitmarker.Size = UDim2.fromOffset(24, 24)
	hitmarker.BackgroundTransparency = 1
	hitmarker.GroupTransparency = 1
	hitmarker.Parent = screenGui

	local uiScale = Instance.new("UIScale")
	uiScale.Name = "UIScale"
	uiScale.Parent = hitmarker

	local MARK_LENGTH = 16
	local MARK_THICKNESS = 2
	local function buildMark(rotation: number): Frame
		local mark = Instance.new("Frame")
		mark.AnchorPoint = Vector2.new(0.5, 0.5)
		mark.Position = UDim2.fromScale(0.5, 0.5)
		mark.Size = UDim2.fromOffset(MARK_LENGTH, MARK_THICKNESS)
		mark.Rotation = rotation
		mark.BackgroundColor3 = Color3.new(1, 1, 1)
		mark.BorderSizePixel = 0
		mark.Parent = hitmarker
		return mark
	end
	buildMark(45)
	buildMark(-45)

	return screenGui
end

local GunHudController = {}
GunHudController.__index = GunHudController

function GunHudController.new(gun: Tool)
	local magazineSize = gun:GetAttribute(WeaponConstants.MAGAZINE_SIZE_ATTRIBUTE) or 0
	local leadingZeros = #tostring(magazineSize)

	local gunHud = buildGunHud(gun)
	gunHud.Gun.Ammo.MagazineLabel.Text = `/{magazineSize}`
	gunHud.Parent = playerGui

	local reticleGui = buildReticleGui()
	reticleGui.Parent = playerGui

	local scaleTweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local transparencyTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local hitmarkerScaleTween = TweenService:Create(reticleGui.Hitmarker.UIScale, scaleTweenInfo, { Scale = 1 })
	local hitmarkerTransparencyTween =
		TweenService:Create(reticleGui.Hitmarker, transparencyTweenInfo, { GroupTransparency = 1 })

	local self = {
		gun = gun,
		gunHud = gunHud,
		reticleGui = reticleGui,
		hitmarkerScaleTween = hitmarkerScaleTween,
		hitmarkerTransparencyTween = hitmarkerTransparencyTween,
		enabled = false,
		leadingZeros = leadingZeros,
		ammo = 0,
		reloading = false,
		trove = Trove.new(),
	}
	setmetatable(self, GunHudController)
	self:initialize()
	return self
end

function GunHudController:initialize()
	self.trove:Connect(self.gunHud:GetPropertyChangedSignal("AbsoluteSize"), function()
		self:updateScale()
	end)

	self.trove:Connect(InputCategorizer.lastInputCategoryChanged, function()
		self:updateAlignment()
	end)

	self:updateScale()
	self:updateAlignment()
end

function GunHudController:updateScale()
	-- Update UI size. This is the same logic used by the default touch controls
	local minScreenSize = math.min(self.gunHud.AbsoluteSize.X, self.gunHud.AbsoluteSize.Y)
	local isSmallScreen = minScreenSize < WeaponConstants.UI_SMALL_SCREEN_THRESHOLD
	self.gunHud.UIScale.Scale = if isSmallScreen then WeaponConstants.UI_SMALL_SCREEN_SCALE else 1
end

function GunHudController:updateAlignment()
	local lastInputCategory = InputCategorizer.getLastInputCategory()
	if lastInputCategory == InputCategorizer.InputCategory.Touch then
		-- Align the gun HUD to the center of the screen, since touch controls cover the bottom right corner
		self.gunHud.Gun.AnchorPoint = Vector2.new(0.5, 1)
		self.gunHud.Gun.Position = UDim2.new(0.5, 0, 1, -65)
	else
		self.gunHud.Gun.AnchorPoint = Vector2.new(1, 1)
		self.gunHud.Gun.Position = UDim2.fromScale(1, 1)
	end
end

function GunHudController:updateAmmoText()
	local zeroText = ""
	local ammoText = ""

	if self.reloading then
		zeroText = string.rep("-", self.leadingZeros)
	else
		ammoText = tostring(self.ammo)
		local numZeros = self.leadingZeros - #ammoText
		if numZeros > 0 then
			-- Add leading zeros to the ammo text, using rich text to give them a higher transparency
			zeroText = string.rep("0", numZeros)
		end
	end

	self.gunHud.Gun.Ammo.AmmoLabel.Text = string.format(AMMO_TEXT_FORMAT_STRING, zeroText, ammoText)
end

function GunHudController:setAmmo(ammo: number)
	self.ammo = ammo
	self:updateAmmoText()
end

function GunHudController:setReloading(reloading: boolean)
	self.reloading = reloading
	self:updateAmmoText()
end

function GunHudController:showHitmarker()
	if self.hitmarkerScaleTween.PlaybackState == Enum.PlaybackState.Playing then
		self.hitmarkerScaleTween:Cancel()
	end
	if self.hitmarkerTransparencyTween.PlaybackState == Enum.PlaybackState.Playing then
		self.hitmarkerTransparencyTween:Cancel()
	end

	self.reticleGui.Hitmarker.GroupTransparency = 0
	self.reticleGui.Hitmarker.UIScale.Scale = 2

	self.hitmarkerScaleTween:Play()
	self.hitmarkerTransparencyTween:Play()
end

function GunHudController:enable()
	if self.enabled then
		return
	end
	self.enabled = true
	self.gunHud.Enabled = true
	self.reticleGui.Enabled = true

	UserInputService.MouseIconEnabled = false
end

function GunHudController:disable()
	if not self.enabled then
		return
	end
	self.enabled = false
	self.gunHud.Enabled = false
	self.reticleGui.Enabled = false

	UserInputService.MouseIconEnabled = true
end

function GunHudController:destroy()
	self:disable()
	self.trove:Destroy()
	self.gunHud:Destroy()
	self.reticleGui:Destroy()
end

return GunHudController
