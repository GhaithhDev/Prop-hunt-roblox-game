--[[
	ToggleMorphService

	Handles ToggleMorphController's RequestMorph/RequestUnmorph remotes.
	Morphing hides every BasePart on the player's character (Transparency = 1,
	CanQuery = false, original values kept so they can be restored) and welds
	a clone of the requested prop Model onto the character. CanQuery = false
	means gunshot raycasts (castRays.luau, which walks the full ancestor chain
	to resolve the Humanoid) pass straight through the hidden body - only the
	attached prop (still queryable) can register a hit. CanCollide is left
	alone so the invisible body still keeps the player standing on the ground.

	watchForDamage briefly reveals the Humanoid health bar/nameplate on
	damage: Roblox hides that display outright when Head.Transparency == 1,
	so it drops to 0.99 (visually indistinguishable) for
	MorphConfig.HeadRevealDuration seconds after each hit, then hides it
	again.
]]

--//Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

--//Configs
local RemoteConfig = require(ReplicatedStorage.Shared.Configs.RemoteConfig)
local Tags = require(ReplicatedStorage.Shared.Configs.Tags)
local MorphConfig = require(ReplicatedStorage.Shared.Configs.MorphConfigs)

--//Packages
local Net = require(ReplicatedStorage.Shared.Packages.Net)

local ToggleMorphService = {}

-- How close (studs) the player's HumanoidRootPart must be to the requested
local MAX_MORPH_DISTANCE = 50

-- [player] = { prop = Model, hidden = { [BasePart] = { Transparency, CanQuery } }, healthConnection }
local activeMorphs = {}

local function getBottomY(model: Model): number
	local cframe, size = model:GetBoundingBox()
	return cframe.Position.Y - size.Y / 2
end

local function hideCharacter(character: Model)
	local hidden = {}
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			hidden[part] = { Transparency = part.Transparency, CanQuery = part.CanQuery }
			part.Transparency = 1
			part.CanQuery = false
		end
	end
	return hidden
end

local function restoreCharacter(hidden)
	for part, state in hidden do
		if part.Parent then
			part.Transparency = state.Transparency
			part.CanQuery = state.CanQuery
		end
	end
end

local function attachProp(character: Model, targetModel: Model): Model?
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return nil
	end

	local prop = targetModel:Clone()

	-- Clone() copies CollectionService tags too, so without this the attached
	-- prop would still read as Morphable - every Hider's MorphPromptController
	-- would then add a "Morph" prompt onto the disguised player's own body.
	CollectionService:RemoveTag(prop, Tags.Morphable)

	-- Lets castRays.luau tell "hit the actual disguise" apart from "hit the
	-- real, hidden body" when deciding whether to credit damage.
	CollectionService:AddTag(prop, Tags.MorphProp)

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

	if state.healthConnection then
		state.healthConnection:Disconnect()
	end

	if state.prop then
		state.prop:Destroy()
	end
	restoreCharacter(state.hidden)

	player:SetAttribute("IsMorph", false)
end

-- Connects Humanoid.HealthChanged and flashes the Head to 0.99 on any
-- decrease for MorphConfig.HeadRevealDuration seconds. The generation
-- counter lets a second hit extend the reveal instead of the first hit's
-- delayed restore cutting it short; comparing activeMorphs[player] against
-- the captured state guards the delayed restore against firing after an
-- unmorph or re-morph.
local function watchForDamage(player: Player, character: Model, humanoid: Humanoid, state): RBXScriptConnection?
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return nil
	end

	local previousHealth = humanoid.Health
	local revealGeneration = 0

	return humanoid.HealthChanged:Connect(function(newHealth)
		local isDamage = newHealth < previousHealth
		previousHealth = newHealth
		if not isDamage then
			return
		end

		revealGeneration += 1
		local thisReveal = revealGeneration
		head.Transparency = 0.99
		head.CanQuery = true

		task.delay(MorphConfig.HeadRevealDuration, function()
			if activeMorphs[player] == state and revealGeneration == thisReveal then
				head.Transparency = 1
				head.CanQuery = false
			end
		end)
	end)
end

-- Shared by the RequestMorph remote handler and the forced-morph fallback.
-- On a first-ever morph, the character is hidden *before* attachProp parents
-- the new prop into it - hideCharacter's GetDescendants() sweep would
-- otherwise also catch (and hide) the prop's own parts. On a switch, the new
-- prop is attached first (reusing the true original transparencies captured
-- at the first morph, not the current already-hidden ones) so a bad
-- targetModel leaves the player's current prop untouched.
local function performMorph(player: Player, character: Model, targetModel: Model): boolean
	local existing = activeMorphs[player]

	local hidden
	if not existing then
		hidden = hideCharacter(character)
	end

	local newProp = attachProp(character, targetModel)
	if not newProp then
		if not existing then
			restoreCharacter(hidden)
		end
		return false
	end

	if existing then
		existing.prop:Destroy()
		hidden = existing.hidden
	end

	local newState = {
		prop = newProp,
		hidden = hidden,
		healthConnection = existing and existing.healthConnection or nil,
	}
	activeMorphs[player] = newState

	if not existing then
		player:SetAttribute("IsMorph", true)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:UnequipTools()
			newState.healthConnection = watchForDamage(player, character, humanoid, newState)
		end
	end

	return true
end

local function morphPlayer(player: Player, targetModel: Instance?)
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

	-- Real flow: any Hider can morph. Test flow: Prop Gun equipped works
	-- regardless of team, so manual testing keeps working.
	local tool = character:FindFirstChild(MorphConfig.RequiredTool)
	local hasTool = tool ~= nil and tool:IsA("Tool")
	local isHider = player.Team ~= nil and player.Team.Name == "Hiders"
	if not hasTool and not isHider then
		return
	end

	local transformsUsed = (player:GetAttribute("MorphCount") :: number?) or 0
	if transformsUsed >= MorphConfig.MaxTransforms then
		return
	end

	if (rootPart.Position - targetModel:GetPivot().Position).Magnitude > MAX_MORPH_DISTANCE then
		return
	end

	if performMorph(player, character, targetModel) then
		player:SetAttribute("MorphCount", transformsUsed + 1)
	end
end

-- Called by RoundService when the Hide phase timer runs out on a Hider who
-- still hasn't morphed - bypasses the transform cap (it's a concealment
-- guarantee, not a player action) but only picks props actually on the live
-- map, since GetTagged also returns Morphable instances sitting unused in
-- ServerStorage.Maps templates.
function ToggleMorphService.ForceRandomMorph(player: Player)
	if player:GetAttribute("IsMorph") then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local candidates = {}
	for _, model in CollectionService:GetTagged(Tags.Morphable) do
		if model:IsA("Model") and model:IsDescendantOf(Workspace) then
			table.insert(candidates, model)
		end
	end
	if #candidates == 0 then
		return
	end

	local targetModel = candidates[math.random(#candidates)]
	if performMorph(player, character, targetModel) then
		local transformsUsed = (player:GetAttribute("MorphCount") :: number?) or 0
		player:SetAttribute("MorphCount", transformsUsed + 1)
	end
end

-- Exposed so other systems (RoundService) can force an eliminated/round-ended
-- Hider to un-morph without going through the RequestUnmorph remote.
ToggleMorphService.Unmorph = unmorphPlayer

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
