--[[
	ToggleMorphService

	Handles ToggleMorphController's RequestMorph/RequestUnmorph remotes.
	Morphing hides every BasePart on the player's character (Transparency = 1,
	original values kept so they can be restored) and welds a clone of the
	requested prop Model onto the character
]]

--//Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

--//Configs
local RemoteConfig = require(ReplicatedStorage.Shared.Configs.RemoteConfig)
local Tags = require(ReplicatedStorage.Shared.Configs.Tags)
local MorphConfig = require(ReplicatedStorage.Shared.Configs.MorphConfigs)

--//Packages
local Net = require(ReplicatedStorage.Shared.Packages.Net)

local ToggleMorphService = {}

-- How close (studs) the player's HumanoidRootPart must be to the requested
local MAX_MORPH_DISTANCE = 50

-- [player] = { prop = Model, hidden = { [BasePart] = originalTransparency } }
local activeMorphs = {}

local function getBottomY(model: Model): number
	local cframe, size = model:GetBoundingBox()
	return cframe.Position.Y - size.Y / 2
end

local function hideCharacter(character: Model)
	local hidden = {}
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			hidden[part] = part.Transparency
			part.Transparency = 1
		end
	end
	return hidden
end

local function restoreCharacter(hidden)
	for part, transparency in hidden do
		if part.Parent then
			part.Transparency = transparency
		end
	end
end

local function attachProp(character: Model, targetModel: Model): Model?
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return nil
	end

	local prop = targetModel:Clone()
	local propPrimary = prop.PrimaryPart or prop:FindFirstChildWhichIsA("BasePart", true)
	if not propPrimary then
		prop:Destroy()
		warn(`Morphable model doesn't have a primary part {prop.Name}`)
		return nil
	end

	local characterBottomY = getBottomY(character)
	local propBottomY = getBottomY(prop)
	local propPivot = prop:GetPivot()
	local propHalfHeight = propPivot.Position.Y - propBottomY

	local _, yaw = rootPart.CFrame:ToEulerAnglesYXZ()
	local targetCFrame = CFrame.new(rootPart.Position.X, characterBottomY + propHalfHeight, rootPart.Position.Z)
		* CFrame.Angles(0, yaw, 0)
	prop:PivotTo(targetCFrame)

	for _, part in prop:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false

			if part ~= propPrimary then
				local partWeld = Instance.new("WeldConstraint")
				partWeld.Part0 = propPrimary
				partWeld.Part1 = part
				partWeld.Parent = part
			end
		end
	end

	local rootWeld = Instance.new("WeldConstraint")
	rootWeld.Part0 = rootPart
	rootWeld.Part1 = propPrimary
	rootWeld.Parent = propPrimary

	prop.Parent = character
	return prop
end

local function unmorphPlayer(player: Player)
	local state = activeMorphs[player]
	if not state then
		return
	end
	activeMorphs[player] = nil

	if state.prop then
		state.prop:Destroy()
	end
	restoreCharacter(state.hidden)

	player:SetAttribute("IsMorph", false)
end

local function morphPlayer(player: Player, targetModel: Instance?)
	if player:GetAttribute("IsMorph") then
		return
	end

	if typeof(targetModel) ~= "Instance" or not targetModel:IsA("Model") then
		return
	end

	if not CollectionService:HasTag(targetModel, Tags.Morphable) then
		return
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not rootPart then
		return
	end

	local tool = character:FindFirstChild(MorphConfig.RequiredTool)
	if not tool or not tool:IsA("Tool") then
		return
	end

	if (rootPart.Position - targetModel:GetPivot().Position).Magnitude > MAX_MORPH_DISTANCE then
		return
	end

	local hidden = hideCharacter(character)

	local prop = attachProp(character, targetModel)
	if not prop then
		return
	end

	activeMorphs[player] = {
		prop = prop,
		hidden = hidden,
	}

	player:SetAttribute("IsMorph", true)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:UnequipTools()
	end
end

local function OnPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function()
		activeMorphs[player] = nil
	end)
end
function ToggleMorphService.Start()
	Net:Connect(RemoteConfig.Morph.RequestMorph.Name, morphPlayer)
	Net:Connect(RemoteConfig.Morph.RequestUnmorph.Name, unmorphPlayer)

	for _, player in Players:GetPlayers() do
		OnPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(OnPlayerAdded)

	Players.PlayerRemoving:Connect(function(player)
		activeMorphs[player] = nil
	end)
end

return ToggleMorphService
