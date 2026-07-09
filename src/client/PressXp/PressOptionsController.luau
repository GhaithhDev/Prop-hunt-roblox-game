local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local LocalPlayer = Players.LocalPlayer

local Tags = require(ReplicatedStorage.Shared.Configs.Tags)
local XpPerPressConfig = require(ReplicatedStorage.Shared.Configs.XpPerPressConfig)

local EQUIPPED_COLOR = BrickColor.new("New Yeller").Color
local UNEQUIPPED_COLOR = BrickColor.new("Lime green").Color
local UNALLOWED_COLOR = Color3.new(125, 114, 109)

local PressOptionsController = {}

local function GetOptions()
	return CollectionService:GetTagged(Tags.BaseXpOptionPart)
end

local function UpdateColors( equippedOption)
	local equippedName = tostring(equippedOption)
	local bestOption = XpPerPressConfig.GetBestOptionForWins(LocalPlayer:WaitForChild("PlayerData"):WaitForChild("Wins").Value)
	
	for _, part in GetOptions() do
		if tonumber(part.Name) > bestOption then
			part.Color = UNALLOWED_COLOR
			continue
		end
		part.Color = (part.Name == equippedName) and EQUIPPED_COLOR or UNEQUIPPED_COLOR
	end
end

function PressOptionsController.Start()

	local playerData = LocalPlayer:WaitForChild("PlayerData")
	local equippedValue = playerData:WaitForChild("EquippedPressOption")

	equippedValue:GetPropertyChangedSignal("Value"):Connect(function()
		UpdateColors( equippedValue.Value)
	end)

	UpdateColors(equippedValue.Value)
end

return PressOptionsController
