--!nocheck
--[[
	TouchInputController

	Code-generated touch shoot/reload buttons, shown only while the player's last
	input was Touch (via InputCategorizer). Same behavior as the original template's
	TouchInputController; the buttons are built with Instance.new instead of cloned
	from a pre-made ScreenGui.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local WeaponConstants = require(ReplicatedStorage.Shared.Configs.WeaponConstants)
local Trove = require(ReplicatedStorage.Shared.Packages.Trove)
local InputCategorizer = require(script.Parent.InputCategorizer)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local function buildButton(name: string, text: string, position: UDim2, anchorPoint: Vector2): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.AnchorPoint = anchorPoint
	button.Position = position
	button.Size = UDim2.fromOffset(70, 70)
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.BackgroundTransparency = 0.6
	button.AutoButtonColor = false
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Text = text

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = button

	return button
end

local function buildTouchGui(): ScreenGui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GunTouchGui"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false

	local uiScale = Instance.new("UIScale")
	uiScale.Name = "UIScale"
	uiScale.Parent = screenGui

	local buttons = Instance.new("Frame")
	buttons.Name = "Buttons"
	buttons.Size = UDim2.fromScale(1, 1)
	buttons.BackgroundTransparency = 1
	buttons.Parent = screenGui

	local shootButton = buildButton("ShootButton", "FIRE", UDim2.new(1, -30, 1, -140), Vector2.new(1, 1))
	shootButton.Parent = buttons

	local reloadButton = buildButton("ReloadButton", "RELOAD", UDim2.new(1, -120, 1, -50), Vector2.new(1, 1))
	reloadButton.Parent = buttons

	return screenGui
end

local TouchInputController = {}
TouchInputController.__index = TouchInputController

function TouchInputController.new(gun: Tool)
	local touchGui = buildTouchGui()
	touchGui.Parent = playerGui

	local self = {
		gun = gun,
		gui = touchGui,
		enabled = false,
		trove = Trove.new(),
	}
	setmetatable(self, TouchInputController)
	return self
end

function TouchInputController:updateScale()
	-- Update UI size. This is the same logic used by the default touch controls
	local minScreenSize = math.min(self.gui.AbsoluteSize.X, self.gui.AbsoluteSize.Y)
	local isSmallScreen = minScreenSize < WeaponConstants.UI_SMALL_SCREEN_THRESHOLD
	self.gui.UIScale.Scale = if isSmallScreen then WeaponConstants.UI_SMALL_SCREEN_SCALE else 1
end

function TouchInputController:enableTouchInput()
	self.gui.Enabled = true
	-- Since we're going to be manually activating the gun with a gui button, we disable the default tool activation
	self.gun.ManualActivationOnly = true
end

function TouchInputController:disableTouchInput()
	self.gui.Enabled = false
	self.gun.ManualActivationOnly = false
end

function TouchInputController:onReloadButtonInput(inputObject: InputObject)
	if inputObject.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	if self.reloadCallback then
		self.reloadCallback()
	end
end

function TouchInputController:onShootButtonInput(inputObject: InputObject)
	if inputObject.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	-- Save this inputObject as the current object being held to shoot. InputObjects are persistent as long
	-- as the user's finger stays down, so we can check later to see if this input has stopped.
	self.shootInputObject = inputObject
	self.gun:Activate()
end

-- Since the user may swipe off of the shoot button by aiming around, we need to listen to all input ended
-- events in order to check when they actually stop holding the shoot button.
function TouchInputController:onInputEnded(inputObject: InputObject)
	if self.shootInputObject == inputObject then
		self.shootInputObject = nil
		self.gun:Deactivate()
	end
end

function TouchInputController:setReloadCallback(callback: () -> ())
	self.reloadCallback = callback
end

function TouchInputController:enable()
	if self.enabled then
		return
	end

	self.enabled = true

	self.trove:Connect(InputCategorizer.lastInputCategoryChanged, function(lastInputCategory)
		self:onLastInputCategoryChanged(lastInputCategory)
	end)

	self.trove:Connect(self.gui:GetPropertyChangedSignal("AbsoluteSize"), function()
		self:updateScale()
	end)

	self.trove:Connect(self.gui.Buttons.ShootButton.InputBegan, function(inputObject: InputObject)
		-- Change events will fire even though we're listening to InputBegan, we need to ignore those
		if inputObject.UserInputState == Enum.UserInputState.Change then
			return
		end
		self:onShootButtonInput(inputObject)
	end)

	self.trove:Connect(self.gui.Buttons.ReloadButton.InputBegan, function(inputObject: InputObject)
		if inputObject.UserInputState == Enum.UserInputState.Change then
			return
		end
		self:onReloadButtonInput(inputObject)
	end)

	self.trove:Connect(UserInputService.InputEnded, function(inputObject: InputObject)
		self:onInputEnded(inputObject)
	end)

	local lastInputCategory = InputCategorizer.getLastInputCategory()
	self:onLastInputCategoryChanged(lastInputCategory)
	self:updateScale()
end

function TouchInputController:disable()
	if not self.enabled then
		return
	end

	self.enabled = false
	self:disableTouchInput()
	self.trove:Clean()
end

function TouchInputController:onLastInputCategoryChanged(lastInputCategory)
	if lastInputCategory == InputCategorizer.InputCategory.Touch then
		self:enableTouchInput()
	else
		self:disableTouchInput()
	end
end

function TouchInputController:destroy()
	self:disable()
	self.gui:Destroy()
end

return TouchInputController
