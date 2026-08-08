local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local Tags = require(ReplicatedStorage.Shared.Configs.Tags)
local TreadmillConfig = require(ReplicatedStorage.Shared.Configs.TreadmillConfig)
local MonetizationConfig = require(ReplicatedStorage.Shared.Configs.MonetizationConfig)
local XpPerPress = require(ReplicatedStorage.Shared.Packages.XpPerPress)
local LevelService = require(ServerScriptService.Server.Level.LevelService)
local DataManager = require(ServerScriptService.Server.Data.Manager)
local MonetizationService = require(ServerScriptService.Server.Monetization.MonetizationService)

-- Each Model here is a personal-treadmill tier (Normal, Gold, Diamond, ...),
-- pre-baked with the same Multiplier/GamePassName/RequiresGamePass attributes
-- as their Workspace.Functional.Treadmills world-placed counterparts.
local PLAYER_TREADMILL_ASSETS = ReplicatedStorage.Shared.Assets.PlayerTreadmills

-- Admin-spawned temporary event treadmills (e.g. RadioactiveTreadmill,
-- UFOTreadmill) - just a Multiplier attribute baked in, no GamePass gating.
local EVENT_TREADMILL_ASSETS = ReplicatedStorage.Shared.Assets.EventTreadmills
local ATTR_REQUIRES_GAMEPASS = "RequiresGamePass"
local ATTR_GAMEPASS_NAME = "GamePassName"
local GATE_NOTIFY_DEBOUNCE = 3 -- seconds between repeat notify+prompt for the same locked-out player

local TreadmillService = {}

local playerTreadmillsFolder: Folder
local eventTreadmillFolder: Folder
local eventTreadmillSpawnPart: BasePart
local currentEventTreadmill: Model?
local ownedTreadmills: { [Player]: Model } = {}
local runAnimTracks: { [Player]: AnimationTrack } = {}
local trackedCharacter: { [Player]: Model } = {}
local standingMultiplier: { [Player]: number } = {}
local gateDebounce: { [Player]: boolean } = {}
local trackedAnimator: { [Player]: Animator } = {}
local lastTimePos: { [Player]: number } = {}
local appliedSpeedMultiplier: { [Player]: number } = {}

local function aabbOverlap(centerA: Vector3, halfA: Vector3, centerB: Vector3, halfB: Vector3, margin: number): boolean
	local delta = centerA - centerB
	return math.abs(delta.X) < (halfA.X + halfB.X + margin)
		and math.abs(delta.Y) < (halfA.Y + halfB.Y + margin)
		and math.abs(delta.Z) < (halfA.Z + halfB.Z + margin)
end

local function overlapsExistingTreadmill(candidate: Model): boolean
	local candidateCFrame, candidateSize = candidate:GetBoundingBox()
	local candidateHalf = candidateSize / 2

	for _, treadmill in CollectionService:GetTagged(Tags.TREADMILL) do
		if not treadmill:IsDescendantOf(workspace) then
			continue
		end
		local otherCFrame, otherSize = treadmill:GetBoundingBox()
		if
			aabbOverlap(
				candidateCFrame.Position,
				candidateHalf,
				otherCFrame.Position,
				otherSize / 2,
				TreadmillConfig.SpawnOverlapMargin
			)
		then
			return true
		end
	end

	return false
end

local function playPopAnimation(model: Model)
	model:ScaleTo(TreadmillConfig.PopStartScale)

	local proxy = Instance.new("NumberValue")
	proxy.Value = TreadmillConfig.PopStartScale

	local tween = TweenService:Create(
		proxy,
		TweenInfo.new(TreadmillConfig.PopAnimationDuration, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Value = 1 }
	)

	local connection
	connection = proxy.Changed:Connect(function(value)
		if not model.Parent then
			connection:Disconnect()
			proxy:Destroy()
			return
		end
		model:ScaleTo(value)
	end)

	tween.Completed:Connect(function()
		connection:Disconnect()
		proxy:Destroy()
	end)

	tween:Play()
end

-- Character:GetPivot() sits at the character's torso/root height, not their feet,
-- so placing the treadmill there directly can bury it inside whatever the player
-- happens to be standing on top of (e.g. a keycap). Raycast down to find the real
-- surface under the character and use that as the ground reference instead.
local function getGroundY(character: Model): number
	local rootPart = character.PrimaryPart
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local origin = rootPart.Position

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	local result = workspace:Raycast(origin, Vector3.new(0, -50, 0), raycastParams)

	if result then
		print(result.Instance)
		return result.Position.Y
	end
	local hipHeight = humanoid and humanoid.HipHeight or 2
	return origin.Y - hipHeight - rootPart.Size.Y / 2
end

-- Places `clone` (already parented/positioned roughly) so the BOTTOM of its real
-- bounding box rests exactly on groundY, regardless of where the model's own
-- PrimaryPart sits within its mesh (it's not necessarily centered).
local function restOnGround(clone: Model, groundY: number)
	local boundingCFrame, boundingSize = clone:GetBoundingBox()
	local currentBottomY = boundingCFrame.Position.Y - boundingSize.Y / 2
	local correction = groundY - currentBottomY
	clone:PivotTo(clone:GetPivot() + Vector3.new(0, correction, 0))
end

-- Root sits partway up the treadmill mesh (roughly at belt/stand height, not the
-- model's true top), so it's a better "stand here" reference than the bounding
-- box top. Keeps the character's horizontal position/facing, only adjusts height.
local function teleportOntoTreadmill(character: Model, clone: Model)
	local rootPart = character.PrimaryPart
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local feetToRootOffset = (humanoid and humanoid.HipHeight or 2) + rootPart.Size.Y / 2

	local standY = clone.PrimaryPart.Position.Y + feetToRootOffset
	local currentPivot = character:GetPivot()
	local rotationOnly = currentPivot - currentPivot.Position
	local newPosition = Vector3.new(currentPivot.Position.X, standY, currentPivot.Position.Z)

	character:PivotTo(CFrame.new(newPosition) * rotationOnly)
end

-- Highest-Multiplier tier the player is eligible for: always eligible if
-- RequiresGamePass is falsy (e.g. "Normal"), otherwise only if they own the
-- matching Treadmills GamePass. Normal (Multiplier=1) naturally wins as the
-- fallback when nothing higher is owned - no special-casing needed.
local function pickTreadmillTemplateForPlayer(player: Player): Model?
	local bestModel: Model? = nil
	local bestMultiplier = -1

	for _, model in PLAYER_TREADMILL_ASSETS:GetChildren() do
		if not model:IsA("Model") then
			continue
		end

		local requiresGamePass = model:GetAttribute(ATTR_REQUIRES_GAMEPASS)
		local gamePassName = model:GetAttribute(ATTR_GAMEPASS_NAME)
		local rebirthRequirement = model:GetAttribute("RebirthRequirement")
		local eligible = not requiresGamePass
			or (gamePassName and MonetizationService.OwnsPass(player, "Treadmills", gamePassName))

		if rebirthRequirement then
			local playerRebirth = DataManager.Get(player, "Rebirths") or 0
			if playerRebirth < rebirthRequirement then
				eligible = false
			end
		end 

		if eligible then
			local multiplier = model:GetAttribute("Multiplier") or 1
			if multiplier > bestMultiplier then
				bestMultiplier = multiplier
				bestModel = model
			end
		end
	end

	return bestModel
end

local function destroyPlayerTreadmill(player: Player)
	local treadmill = ownedTreadmills[player]
	if not treadmill then
		return
	end
	ownedTreadmills[player] = nil
	treadmill:Destroy()
end

local function spawnPlayerTreadmill(player: Player)
	local character = player.Character
	if not character then
		warn(`TreadmillService: {player.Name} tried to spawn a treadmill with no character`)
		return
	end
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")

	if not humanoid or humanoid.FloorMaterial == Enum.Material.Air then
		Net:RemoteEvent("Notify"):FireClient(player, "error", "Can't spawn treadmill in air")
		return
	end
	local spawnCFrame = character:GetPivot()

	local template = pickTreadmillTemplateForPlayer(player)
	if not template then
		warn(`TreadmillService: no eligible PlayerTreadmills template found for {player.Name}`)
		return
	end

	local clone = template:Clone()
	clone:PivotTo(spawnCFrame)
	restOnGround(clone, getGroundY(character))

	if overlapsExistingTreadmill(clone) then
		clone:Destroy()
		Net:RemoteEvent("Notify"):FireClient(player, "error", "That spot overlaps another treadmill!")
		return
	end

	clone:SetAttribute("OwnerId", player.UserId)
	CollectionService:AddTag(clone, Tags.TREADMILL)
	clone.Parent = playerTreadmillsFolder

	ownedTreadmills[player] = clone
	playPopAnimation(clone)
	teleportOntoTreadmill(character, clone)
end

local function onToggleSpawn(player: Player)
	if ownedTreadmills[player] then
		destroyPlayerTreadmill(player)
	else
		spawnPlayerTreadmill(player)
	end
end

local function findStandingPlayers(treadmill: Model): { [Player]: boolean }
	if not treadmill:IsDescendantOf(workspace) then
		return {}
	end

	local boundingCFrame, boundingSize = treadmill:GetBoundingBox()
	local hitboxSize = boundingSize + Vector3.new(0, TreadmillConfig.StandHitboxVerticalPadding, 0)

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { treadmill }
	local parts = workspace:GetPartBoundsInBox(boundingCFrame, hitboxSize, params)

	local players = {}
	for _, part in parts do
		local charModel = part:FindFirstAncestorOfClass("Model")
		local plr = charModel and Players:GetPlayerFromCharacter(charModel)
		if plr then
			players[plr] = true
		end
	end
	return players
end

local function getOrCreateRunTrack(player: Player): AnimationTrack?
	local character = player.Character
	if not character then
		return nil
	end

	if trackedCharacter[player] == character and runAnimTracks[player] then
		return runAnimTracks[player]
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 5)
	if not animator then
		return nil
	end

	local animate = character:WaitForChild("Animate", 5)
	local runFolder = animate and animate:WaitForChild("run", 5)
	local runAnim = runFolder and runFolder:WaitForChild("RunAnim", 5)
	if not runAnim then
		warn(`TreadmillService: could not find run animation for {player.Name}`)
		return nil
	end

	local oldTrack = runAnimTracks[player]
	if oldTrack then
		oldTrack:Stop()
	end

	local track = animator:LoadAnimation(runAnim)
	track.Looped = true
	runAnimTracks[player] = track
	trackedCharacter[player] = character
	return track
end

local function addDebounce(player: Player)
	gateDebounce[player] = true
	task.delay(GATE_NOTIFY_DEBOUNCE, function()
		gateDebounce[player] = nil
	end)
end

local function notifyAndPromptLockedTreadmill(plr: Player, passId: string)
	if gateDebounce[plr] then
		return
	end
	addDebounce(plr)

	local productId = MonetizationConfig.GamePasses.Treadmills[passId]
	if not productId or productId == 0 then
		warn(`TreadmillService: "{passId}" has no valid ProductId in MonetizationConfig - not prompting`)
		return
	end
	MonetizationService.PromptPurchaseById(plr, productId)
end

local function onRebirthLocked(player: Player, rebirthReq: number)
	if gateDebounce[player] then
		return
	end
	addDebounce(player)
	Net:RemoteEvent("Notify"):FireClient(player,"error","Need " .. rebirthReq .. " Rebirth")
end

local function updateTreadmills()
	local currentlyStanding: { [Player]: { multiplier: number, treadmill: Model } } = {}

	-- Event treadmills take priority over everything else (future feature; GetTagged
	-- returns {} today since nothing spawns EVENT_TREADMILL-tagged instances yet).
	for _, treadmill in CollectionService:GetTagged(Tags.EVENT_TREADMILL) do
		local multiplier = treadmill:GetAttribute("Multiplier") or 1
		for plr in findStandingPlayers(treadmill) do
			currentlyStanding[plr] = { multiplier = multiplier, treadmill = treadmill }
		end
	end

	for _, treadmill in CollectionService:GetTagged(Tags.TREADMILL) do
		local ownerId = treadmill:GetAttribute("OwnerId")
		local multiplier = treadmill:GetAttribute("Multiplier") or 1
		local passId = treadmill:GetAttribute(ATTR_REQUIRES_GAMEPASS) and treadmill:GetAttribute(ATTR_GAMEPASS_NAME)

		for plr in findStandingPlayers(treadmill) do
			if currentlyStanding[plr] then continue end -- already claimed by a higher-priority event treadmill
			if ownerId and ownerId ~= 0 and ownerId ~= plr.UserId then continue end -- someone else's personal treadmill: scenery only

			if passId and not MonetizationService.OwnsPass(plr, "Treadmills", passId) then
				notifyAndPromptLockedTreadmill(plr, passId)
				continue -- locked: no multiplier/XP benefit for non-owners
			end

			currentlyStanding[plr] = { multiplier = multiplier, treadmill = treadmill }
		end
	end

	for _, plr in Players:GetPlayers() do
		local standing = currentlyStanding[plr]
		local multiplier = standing and standing.multiplier
		if multiplier then
			if standingMultiplier[plr] ~= multiplier then
				DataManager.SyncToClient(plr, "TreadmillMultiplier", multiplier)
			end
			standingMultiplier[plr] = multiplier

			local track = getOrCreateRunTrack(plr)
			local desiredSpeed = math.clamp(multiplier / 2, 1, 5)

			if track then
				local humanoid = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
				local liveAnimator = humanoid and humanoid:FindFirstChildOfClass("Animator")
				local reallyPlaying = false
				if liveAnimator then
					for _, t in liveAnimator:GetPlayingAnimationTracks() do
						if t == track then
							reallyPlaying = true
							break
						end
					end
				end

				if not reallyPlaying then
					track = getOrCreateRunTrack(plr, true)
					if track then
						track:Play(0.15)
						track:AdjustSpeed(desiredSpeed)
						appliedSpeedMultiplier[plr] = multiplier
					end
				elseif appliedSpeedMultiplier[plr] ~= multiplier then
					track:AdjustSpeed(desiredSpeed)
					appliedSpeedMultiplier[plr] = multiplier
				end
			end

			LevelService.GrantXp(plr, XpPerPress.GetAmountForPlayer(plr))
		else
			if standingMultiplier[plr] ~= nil then
				DataManager.SyncToClient(plr, "TreadmillMultiplier", 1)
			end
			standingMultiplier[plr] = nil
			appliedSpeedMultiplier[plr] = nil
			local track = runAnimTracks[plr]
			if track and track.IsPlaying then track:Stop() end
		end

		local ownTreadmill = ownedTreadmills[plr]
		if ownTreadmill and (not standing or standing.treadmill ~= ownTreadmill) then
			destroyPlayerTreadmill(plr)
		end
	end
end

function TreadmillService.GetMultiplierForPlayer(player: Player): number
	return standingMultiplier[player] or 1
end

-- Only one spawn point exists, so a new spawn replaces whatever event
-- treadmill is currently active rather than stacking/overlapping with it.
function TreadmillService.SpawnEventTreadmill(name: string, duration: number)
	local lowerName = name:lower()
	local template: Model? = nil
	for _, child in EVENT_TREADMILL_ASSETS:GetChildren() do
		if child:IsA("Model") and child.Name:lower() == lowerName then
			template = child
			break
		end
	end

	if not template then
		warn(`TreadmillService: "{name}" has no matching Model in Assets.EventTreadmills - skipping`)
		return
	end

	if currentEventTreadmill then
		currentEventTreadmill:Destroy()
		currentEventTreadmill = nil
	end

	local clone = template:Clone()
	clone:PivotTo(eventTreadmillSpawnPart.CFrame)
	CollectionService:AddTag(clone, Tags.EVENT_TREADMILL)
	clone.Parent = eventTreadmillFolder

	currentEventTreadmill = clone

	task.delay(duration, function()
		if currentEventTreadmill == clone then
			currentEventTreadmill = nil
			clone:Destroy()
		end
	end)
end

function TreadmillService.Start()
	for _, treadmill in workspace.Functional.Treadmills:GetChildren() do
		if treadmill:IsA("Model") then
			CollectionService:AddTag(treadmill, Tags.TREADMILL)
		end
	end

	playerTreadmillsFolder = workspace.Functional:FindFirstChild("PlayerTreadmills")
	if not playerTreadmillsFolder then
		playerTreadmillsFolder = Instance.new("Folder")
		playerTreadmillsFolder.Name = "PlayerTreadmills"
		playerTreadmillsFolder.Parent = workspace.Functional
	end

	eventTreadmillSpawnPart = workspace.Functional:WaitForChild("EventTreadmillSpawnCFrame")
	eventTreadmillFolder = workspace.Functional:FindFirstChild("EventTreadmills")
	if not eventTreadmillFolder then
		eventTreadmillFolder = Instance.new("Folder")
		eventTreadmillFolder.Name = "EventTreadmills"
		eventTreadmillFolder.Parent = workspace.Functional
	end

	Net:Connect("ToggleSpawn", onToggleSpawn)

	Players.PlayerRemoving:Connect(function(player)
		destroyPlayerTreadmill(player)
		local track = runAnimTracks[player]
		if track then
			track:Stop()
			track:Destroy()
		end
		runAnimTracks[player] = nil
		trackedCharacter[player] = nil
		standingMultiplier[player] = nil
		gateDebounce[player] = nil
	end)

	task.spawn(function()
		while task.wait(TreadmillConfig.XpTickInterval) do
			updateTreadmills()
		end
	end)
end

return TreadmillService
