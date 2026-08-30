--[[
	MorphPromptController

	Adds a ProximityPrompt to every Morphable-tagged model that's in the local
	player's streamed-in render range, for Hiders only. CollectionService's tag
	added/removed signals double as the streaming in/out signal here - with
	StreamingEnabled, a part (and its tags) only exists in a client's DataModel
	while it's streamed in, so GetInstanceAddedSignal/RemovedSignal fire on
	stream in/out, not just on CollectionService:AddTag/RemoveTag calls.
	Prompts are created purely client-side (never replicated), so only Hiders
	ever see or can trigger them. Triggered fires the same RequestMorph remote
	ToggleMorphController (Prop Gun testing path) uses - ToggleMorphService
	handles both the same way server-side.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteConfig = require(ReplicatedStorage.Shared.Configs.RemoteConfig)
local Tags = require(ReplicatedStorage.Shared.Configs.Tags)
local MorphConfig = require(ReplicatedStorage.Shared.Configs.MorphConfigs)

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local Trove = require(ReplicatedStorage.Shared.Packages.Trove)

local LocalPlayer = Players.LocalPlayer

local MorphPromptController = {}

local PROMPT_MAX_DISTANCE = 8
local PROMPT_HOLD_DURATION = 0.3

local trove = Trove.new()
local modelTroves: { [Model]: Trove.Trove } = {}

local function canUseMorphPrompts(): boolean
	print(`Player team is {LocalPlayer.Team.Name} `)
	local team = LocalPlayer.Team
	if not team or team.Name ~= "Hiders" then
		print("Player cannot morph now, no prompts")
		return false
	end
	local transformsUsed = (LocalPlayer:GetAttribute("MorphCount") :: number?) or 0
	return transformsUsed < MorphConfig.MaxTransforms
end

local function getPromptParent(model: Model): BasePart?
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

local function createPrompt(model: Model, modelTrove: Trove.Trove, part: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Morph"
	prompt.ObjectText = model.Name
	prompt.HoldDuration = PROMPT_HOLD_DURATION
	prompt.MaxActivationDistance = PROMPT_MAX_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	modelTrove:Add(prompt)

	modelTrove:Connect(prompt.Triggered, function()
		Net:RemoteEvent(RemoteConfig.Morph.RequestMorph.Name):FireServer(model)
	end)
end

local function addPrompt(model: Model)
	if modelTroves[model] or not canUseMorphPrompts() then
		return
	end

	local modelTrove = trove:Extend()
	modelTroves[model] = modelTrove

	local existingPart = getPromptParent(model)
	if existingPart then
		createPrompt(model, modelTrove, existingPart)
		return
	end

	-- StreamingEnabled can deliver the Model (and its Morphable tag) before
	-- any of its BaseParts have streamed in - wait for one instead of
	-- silently never adding a prompt.
	local waitConnection: RBXScriptConnection
	waitConnection = model.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			modelTrove:Remove(waitConnection)
			createPrompt(model, modelTrove, descendant)
		end
	end)
	modelTrove:Add(waitConnection)
end

local function removePrompt(model: Model)
	local modelTrove = modelTroves[model]
	if not modelTrove then
		return
	end
	modelTroves[model] = nil
	trove:Remove(modelTrove)
end

local function refreshAllPrompts()
	if canUseMorphPrompts() then
		for _, model in CollectionService:GetTagged(Tags.Morphable) do
			if model:IsA("Model") then
				addPrompt(model)
			end
		end
	else
		for model in modelTroves do
			removePrompt(model)
		end
	end
end

function MorphPromptController.Start()
	trove:Connect(CollectionService:GetInstanceAddedSignal(Tags.Morphable), function(instance)
		if instance:IsA("Model") then
			addPrompt(instance)
		end
	end)

	trove:Connect(CollectionService:GetInstanceRemovedSignal(Tags.Morphable), function(instance)
		removePrompt(instance :: Model)
	end)

	trove:Connect(LocalPlayer:GetPropertyChangedSignal("Team"), refreshAllPrompts)
	trove:Connect(LocalPlayer:GetAttributeChangedSignal("MorphCount"), refreshAllPrompts)

	refreshAllPrompts()
end

return MorphPromptController
