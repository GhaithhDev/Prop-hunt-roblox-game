--//Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--//Packages
local Net = require(ReplicatedStorage.Shared.Packages.Net)
local SoundUtils = require(ReplicatedStorage.Shared.Packages.SoundUtils)

--//Configs
local Tags = require(ReplicatedStorage.Shared.Configs.Tags)
local RemoteConfig = require(ReplicatedStorage.Shared.Configs.RemoteConfig)
local MorphConfig = require(ReplicatedStorage.Shared.Configs.MorphConfigs)

local LOOK_DISTANCE = 50
local HIGHLIGHT_COLOR = Color3.fromRGB(0, 255, 0)
local HIGHLIGHT_FILL_TRANSPARENCY = 0.5
local HIGHLIGHT_OUTLINE_TRANSPARENCY = 0

--//Cache
local ToggleMorphController = {}
local player = Players.LocalPlayer
local highlightedTarget: Model? = nil
local highlight: Highlight? = nil

local function getLookTarget(): BasePart?
	local camera = Workspace.CurrentCamera
	if not camera or not player then
		return nil
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character }

	local origin = camera.CFrame.Position
	local direction = camera.CFrame.LookVector * LOOK_DISTANCE

	local result = Workspace:Raycast(origin, direction, params)
	if not result or not result.Instance:IsA("BasePart") then
		return nil
	end

	return result.Instance
end

local function findMorphableModel(part: BasePart): Model?
	local current: Instance? = part.Parent
	while current do
		if current:IsA("Model") and CollectionService:HasTag(current, Tags.Morphable) then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function GetLookedAtMorphable(): Model?
	local target = getLookTarget()
	if not target then
		return nil
	end

	return findMorphableModel(target)
end

local function hasRequiredToolEquipped(): boolean
	local character = player.Character
	if not character then
		return false
	end

	local tool = character:FindFirstChild(MorphConfig.RequiredTool)
	return tool ~= nil and tool:IsA("Tool")
end

local function clearHighlight()
	if highlight then
		highlight:Destroy()
		highlight = nil
	end
	highlightedTarget = nil
end

local function highlightTarget(target: Model)
	local newHighlight = Instance.new("Highlight")
	newHighlight.FillColor = HIGHLIGHT_COLOR
	newHighlight.OutlineColor = HIGHLIGHT_COLOR
	newHighlight.FillTransparency = HIGHLIGHT_FILL_TRANSPARENCY
	newHighlight.OutlineTransparency = HIGHLIGHT_OUTLINE_TRANSPARENCY
	newHighlight.Parent = target

	highlight = newHighlight
	highlightedTarget = target
end

local function update()
	if player:GetAttribute("IsMorph") or not hasRequiredToolEquipped() then
		print("player is already morph or doesn't have requried tool")
		clearHighlight()
		return
	end

	local target = GetLookedAtMorphable()
	if target == highlightedTarget then
		print("Same target, no need for highlight")
		return
	end

	clearHighlight()
	if target then
		print("new target, adding highlight")
		highlightTarget(target)
	end
end

function ToggleMorphController.ToggleMorph()
	
	if player:GetAttribute("IsMorph") then
		Net:RemoteEvent(RemoteConfig.Morph.RequestUnmorph.Name):FireServer()
		return
	end

	local target = GetLookedAtMorphable()
	print(target)
	if not target then
		return
	end

	Net:RemoteEvent(RemoteConfig.Morph.RequestMorph.Name):FireServer(target)
end

-- Fires off the IsMorph attribute itself (not ToggleMorph) so it only plays
-- once the server actually confirms the morph/unmorph, not on every request
-- - a rejected RequestMorph (no tool, too far, etc.) stays silent.
local function onIsMorphChanged()
	SoundUtils.PlayLocalSound(SoundService.SFX.ToggleMorph)
end

local function onInputBegan(input: InputObject, gameProcessedEvent: boolean)
	if gameProcessedEvent then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.ButtonR2 then
		ToggleMorphController.ToggleMorph()
	end
end

function ToggleMorphController.Start()
	RunService.RenderStepped:Connect(update)
	UserInputService.InputBegan:Connect(onInputBegan)
	player:GetAttributeChangedSignal("IsMorph"):Connect(onIsMorphChanged)
end

return ToggleMorphController
