local Players = game:GetService("Players")

local LocalPlayer = Players.LocalPlayer

local EQUIPPED_COLOR = BrickColor.new("New Yeller").Color
local UNEQUIPPED_COLOR = BrickColor.new("Lime green").Color

local PressOptionsController = {}

local function UpdateColors(optionsFolder, equippedOption)
	local equippedName = tostring(equippedOption)
	for _, part in optionsFolder:GetChildren() do
		part.Color = (part.Name == equippedName) and EQUIPPED_COLOR or UNEQUIPPED_COLOR
	end
end

function PressOptionsController.Start()
	local optionsFolder = workspace:WaitForChild("Functional"):WaitForChild("XpPerPressOptions")

	local playerData = LocalPlayer:WaitForChild("PlayerData")
	local equippedValue = playerData:WaitForChild("EquippedPressOption")

	equippedValue:GetPropertyChangedSignal("Value"):Connect(function()
		UpdateColors(optionsFolder, equippedValue.Value)
	end)

	UpdateColors(optionsFolder, equippedValue.Value)
end

return PressOptionsController
