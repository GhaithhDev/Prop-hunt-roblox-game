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
	local playerData = LocalPlayer:WaitForChild("PlayerData")
	local wins = playerData:WaitForChild("Wins").Value
	local currentWorld = playerData:WaitForChild("World").Value
	local options = GetOptions()
	for _, part in options do
		local optionIndex = tonumber(part.Name)
		if not optionIndex then continue end

		-- Each part's own World attribute picks which world's ladder it belongs to -
		-- parts in different worlds can reuse the same 1..N names, so both the
		-- affordability check and the equipped check must be world-scoped.
		local partWorld = part:GetAttribute("World") or 1
		local bestOption = XpPerPressConfig.GetBestOptionForWins(wins, partWorld)
		if optionIndex > bestOption then
			part.Color = UNALLOWED_COLOR
			continue
		end
		part.Color = (partWorld == currentWorld and part.Name == equippedName) and EQUIPPED_COLOR or UNEQUIPPED_COLOR
	end
end

local function OnOptionAdded()
	local playerData = LocalPlayer:WaitForChild("PlayerData")
	local equippedValue = playerData:WaitForChild("EquippedPressOption")
	UpdateColors(equippedValue.Value)
end

function PressOptionsController.Start()

	local playerData = LocalPlayer:WaitForChild("PlayerData")
	local equippedValue = playerData:WaitForChild("EquippedPressOption")
	local winsValue = playerData:WaitForChild("Wins")
	local worldValue = playerData:WaitForChild("World")

	equippedValue:GetPropertyChangedSignal("Value"):Connect(function()
		UpdateColors( equippedValue.Value)
	end)

	-- Wins changing (spent or earned) can flip which options are affordable
	-- even when it doesn't also change the equipped option itself.
	winsValue:GetPropertyChangedSignal("Value"):Connect(function()
		UpdateColors(equippedValue.Value)
	end)

	-- Switching worlds changes which per-world ladder every part's affordability/
	-- equipped state resolves against.
	worldValue:GetPropertyChangedSignal("Value"):Connect(function()
		UpdateColors(equippedValue.Value)
	end)

	UpdateColors(equippedValue.Value)

	CollectionService:GetInstanceAddedSignal(Tags.BaseXpOptionPart):Connect(OnOptionAdded)
end

return PressOptionsController
