local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local Tags = require(ReplicatedStorage.Shared.Configs.Tags)
local TreadmillConfig = require(ReplicatedStorage.Shared.Configs.TreadmillConfig)
local XpPerPress = require(ReplicatedStorage.Shared.Packages.XpPerPress)
local LevelService = require(ServerScriptService.Server.Level.LevelService)
local DataManager = require(ServerScriptService.Server.Data.Manager)

local TreadmillTemplate = ReplicatedStorage.Shared.Assets.Treadmills.PlayerTreadMill
local SafeZonePart = workspace.Functional.Areas.Safe

local TreadmillService = {}

local playerTreadmillsFolder: Folder
local ownedTreadmills: { [Player]: Model } = {}
local runAnimTracks: { [Player]: AnimationTrack } = {}
local trackedCharacter: { [Player]: Model } = {}
local standingMultiplier: { [Player]: number } = {}

local function isInsideSafeZone(position: Vector3): boolean
	local halfSize = SafeZonePart.Size / 2
	local localPosition = SafeZonePart.CFrame:PointToObjectSpace(position)
	return math.abs(localPosition.X) <= halfSize.X
		and math.abs(localPosition.Y) <= halfSize.Y
		and math.abs(localPosition.Z) <= halfSize.Z
end

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
		local otherCFrame, otherSize = treadmill:GetBoundingBox()
		if aabbOverlap(candidateCFrame.Position, candidateHalf, otherCFrame.Position, otherSize / 2, TreadmillConfig.SpawnOverlapMargin) then
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

local function destroyPlayerTreadmill(player: Player)
	local treadmill = ownedTreadmills[player]
	if not treadmill then return end
	ownedTreadmills[player] = nil
	treadmill:Destroy()
end

local function spawnPlayerTreadmill(player: Player)
	local character = player.Character
	if not character then
		warn(`TreadmillService: {player.Name} tried to spawn a treadmill with no character`)
		return
	end

	local spawnCFrame = character:GetPivot()
	if not isInsideSafeZone(spawnCFrame.Position) then
		warn(`TreadmillService: {player.Name} tried to spawn a treadmill outside the Safe zone`)
		return
	end

	local clone = TreadmillTemplate:Clone()
	clone:PivotTo(spawnCFrame)
	restOnGround(clone, getGroundY(character))

	if overlapsExistingTreadmill(clone) then
		clone:Destroy()
		warn(`TreadmillService: {player.Name} tried to spawn a treadmill overlapping an existing one`)
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
	if not character then return nil end

	if trackedCharacter[player] == character and runAnimTracks[player] then
		return runAnimTracks[player]
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return nil end
	local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 5)
	if not animator then return nil end

	local animate = character:WaitForChild("Animate", 5)
	local runFolder = animate and animate:WaitForChild("run", 5)
	local runAnim = runFolder and runFolder:WaitForChild("RunAnim", 5)
	if not runAnim then
		warn(`TreadmillService: could not find run animation for {player.Name}`)
		return nil
	end

	local oldTrack = runAnimTracks[player]
	if oldTrack then oldTrack:Stop() end

	local track = animator:LoadAnimation(runAnim)
	track.Looped = true
	runAnimTracks[player] = track
	trackedCharacter[player] = character
	return track
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
		for plr in findStandingPlayers(treadmill) do
			if currentlyStanding[plr] then continue end -- already claimed by a higher-priority event treadmill
			if ownerId and ownerId ~= 0 and ownerId ~= plr.UserId then continue end -- someone else's personal treadmill: scenery only
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
			if track and not track.IsPlaying then track:Play() end
			LevelService.GrantXp(plr, XpPerPress.GetAmountForPlayer(plr))
		else
			if standingMultiplier[plr] ~= nil then
				DataManager.SyncToClient(plr, "TreadmillMultiplier", 1)
			end
			standingMultiplier[plr] = nil
			local track = runAnimTracks[plr]
			if track and track.IsPlaying then track:Stop() end
		end

		-- Auto-despawn a player's personal treadmill the moment they're no longer
		-- standing on it (walked off, or an event treadmill took over that spot).
		local ownTreadmill = ownedTreadmills[plr]
		if ownTreadmill and (not standing or standing.treadmill ~= ownTreadmill) then
			destroyPlayerTreadmill(plr)
		end
	end
end

function TreadmillService.GetMultiplierForPlayer(player: Player): number
	return standingMultiplier[player] or 1
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
	end)

	task.spawn(function()
		while task.wait(TreadmillConfig.XpTickInterval) do
			updateTreadmills()
		end
	end)
end

return TreadmillService
