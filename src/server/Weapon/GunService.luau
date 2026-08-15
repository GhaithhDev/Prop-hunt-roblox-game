--[[
	GunService

	Server side of the gun system: validates and resolves Shoot/Reload requests,
	applies damage, replicates shots to other clients, keeps every Tags.Gun-tagged
	Tool's stat attributes/ammo initialized, and tags character/accessory parts so
	raycasts pass through them correctly. Ported from the FPS template's server
	Blaster script + AccessoryFiltering script, validation inlined as plain guard
	functions (matching this codebase's existing style, e.g. ToggleMorphService)
	instead of porting a separate type-validation framework.

	Exposes `GunService.Tagged`/`GunService.Eliminated` signals (fired after damage
	is applied) so other systems - e.g. round/score tracking - can react without
	this module needing to know about them.
]]

--//Services
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

--//Configs
local WeaponConstants = require(ReplicatedStorage.Shared.Configs.WeaponConstants)
local WeaponConfigs = require(ReplicatedStorage.Shared.Configs.WeaponConfigs)
local RemoteConfig = require(ReplicatedStorage.Shared.Configs.RemoteConfig)
local Tags = require(ReplicatedStorage.Shared.Configs.Tags)

--//Packages
local Net = require(ReplicatedStorage.Shared.Packages.Net)

--//Weapon utility
local getRayDirections = require(ReplicatedStorage.Shared.Weapon.Utility.getRayDirections)
local castRays = require(ReplicatedStorage.Shared.Weapon.Utility.castRays)
local canPlayerDamageHumanoid = require(ReplicatedStorage.Shared.Weapon.Utility.canPlayerDamageHumanoid)

local GunService = {}

local replicateShotRemote = nil

local taggedBindable = Instance.new("BindableEvent")
local eliminatedBindable = Instance.new("BindableEvent")
GunService.Tagged = taggedBindable.Event
GunService.Eliminated = eliminatedBindable.Event

--=============================================================================
-- Validation
--=============================================================================

local TIMESTAMP_BUFFER_CONSTANT = 1
local POSITION_BUFFER_CONSTANT = 5
local POSITION_BUFFER_FACTOR = 0.4
local DIRECTION_BUFFER_CONSTANT = 10
local WALL_DISTANCE_BUFFER_CONSTANT = 5

local function isValidTaggedTable(tagged: any): boolean
	if typeof(tagged) ~= "table" then
		return false
	end

	for index, humanoid in tagged do
		if typeof(index) ~= "string" then
			return false
		end
		if typeof(humanoid) ~= "Instance" or not humanoid:IsA("Humanoid") then
			return false
		end
	end

	return true
end

local function validateShootArguments(timestamp: any, gun: any, origin: any, tagged: any): boolean
	if typeof(timestamp) ~= "number" then
		return false
	end
	if typeof(gun) ~= "Instance" or not gun:IsA("Tool") then
		return false
	end
	if typeof(origin) ~= "CFrame" then
		return false
	end
	if not isValidTaggedTable(tagged) then
		return false
	end

	return true
end

local function validateShot(player: Player, timestamp: number, gun: Tool, origin: CFrame): boolean
	-- Validate timestamp
	local now = Workspace:GetServerTimeNow()
	if timestamp > now then
		return false
	end
	if timestamp < now - TIMESTAMP_BUFFER_CONSTANT then
		return false
	end

	-- Make sure the character exists, is alive, and has a PrimaryPart
	local character = player.Character
	if not character then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end
	if humanoid.Health <= 0 then
		return false
	end
	local primaryPart = character.PrimaryPart
	if not primaryPart then
		return false
	end

	-- Make sure the gun is equipped
	if gun.Parent ~= character then
		return false
	end

	-- Make sure the gun is not being reloaded
	if gun:GetAttribute(WeaponConstants.RELOADING_ATTRIBUTE) then
		return false
	end

	-- Make sure the gun has enough ammo
	local ammo = gun:GetAttribute(WeaponConstants.AMMO_ATTRIBUTE)
	if not ammo or ammo <= 0 then
		return false
	end

	-- Make sure the origin position is within a reasonable distance from the character
	local distance = (primaryPart.Position - origin.Position).Magnitude
	local maxDistance = POSITION_BUFFER_CONSTANT + primaryPart.AssemblyLinearVelocity.Magnitude * POSITION_BUFFER_FACTOR
	if distance > maxDistance then
		return false
	end

	return true
end

local function validateTag(
	player: Player,
	taggedHumanoid: Humanoid,
	position: Vector3,
	direction: Vector3,
	rayResult: castRays.RayResult
): boolean
	-- Make sure the player is actually allowed to damage this humanoid. No team killing!
	if not canPlayerDamageHumanoid(player, taggedHumanoid) then
		return false
	end

	local character = taggedHumanoid:FindFirstAncestorOfClass("Model")
	if not character then
		return false
	end

	local pivot = character:GetPivot()
	local characterOffset = pivot.Position - position
	local characterDistance = characterOffset.Magnitude
	local rayDistance = (position - rayResult.position).Magnitude

	-- If the server's version of the ray hits static geometry before the player, then we know the shot
	-- the client reported could not be made.
	if rayDistance < characterDistance - WALL_DISTANCE_BUFFER_CONSTANT then
		return false
	end

	-- Make sure the ray is actually aiming within a reasonable distance of the character
	local maxAngle = math.atan(DIRECTION_BUFFER_CONSTANT / characterDistance)
	local angle = characterOffset:Angle(direction)
	if angle > maxAngle then
		return false
	end

	return true
end

local function validateReload(player: Player, gun: Tool): boolean
	local character = player.Character
	if not character then
		return false
	end

	if gun.Parent ~= character then
		return false
	end

	if gun:GetAttribute(WeaponConstants.RELOADING_ATTRIBUTE) then
		return false
	end

	return true
end

--=============================================================================
-- Shoot / Reload
--=============================================================================

local function onShootEvent(
	player: Player,
	timestamp: number,
	gun: Tool,
	origin: CFrame,
	tagged: { [string]: Humanoid }
)
	if not validateShootArguments(timestamp, gun, origin, tagged) then
		return
	end

	if not validateShot(player, timestamp, gun, origin) then
		return
	end

	local spread = gun:GetAttribute(WeaponConstants.SPREAD_ATTRIBUTE) or 0
	local raysPerShot = gun:GetAttribute(WeaponConstants.RAYS_PER_SHOT_ATTRIBUTE) or 1
	local range = gun:GetAttribute(WeaponConstants.RANGE_ATTRIBUTE) or 1000
	local rayRadius = gun:GetAttribute(WeaponConstants.RAY_RADIUS_ATTRIBUTE) or 0.1
	local damage = gun:GetAttribute(WeaponConstants.DAMAGE_ATTRIBUTE) or 0

	-- Subtract ammo
	local ammo = gun:GetAttribute(WeaponConstants.AMMO_ATTRIBUTE)
	gun:SetAttribute(WeaponConstants.AMMO_ATTRIBUTE, ammo - 1)

	-- The timestamp that was passed by the client also serves as the seed for the gun's random spread.
	-- This allows us to recalculate the spread accurately on the server relative to the look direction, rather than simply
	-- accepting a direction or directions from the client.
	local spreadAngle = math.rad(spread)
	local rayDirections = getRayDirections(origin, raysPerShot, spreadAngle, timestamp)
	for index, direction in rayDirections do
		rayDirections[index] = direction * range
	end
	-- Raycast against static geometry only
	local rayResults = castRays(player, origin.Position, rayDirections, rayRadius, true)

	-- Validate hits
	for indexString, taggedHumanoid in tagged do
		local index = tonumber(indexString)
		if not index then
			continue
		end
		local rayResult = rayResults[index]
		if not rayResults[index] then
			continue
		end
		local rayDirection = rayDirections[index]
		if not rayDirection then
			continue
		end

		if not validateTag(player, taggedHumanoid, origin.Position, rayDirection, rayResult) then
			continue
		end

		rayResult.taggedHumanoid = taggedHumanoid

		-- Align the rayResult position to the tagged humanoid, so replicated shots don't visually
		-- pass through the character they hit.
		local model = taggedHumanoid:FindFirstAncestorOfClass("Model")
		if model then
			local modelPosition = model:GetPivot().Position
			local distance = (modelPosition - origin.Position).Magnitude
			rayResult.position = origin.Position + rayDirection.Unit * distance
		end

		if taggedHumanoid.Health <= 0 then
			continue
		end

		taggedHumanoid:TakeDamage(damage)
		taggedBindable:Fire(player, taggedHumanoid, damage)

		if taggedHumanoid.Health <= 0 then
			eliminatedBindable:Fire(player, taggedHumanoid, damage)
		end
	end

	-- Apply physics impulse to unanchored parts that were hit
	local force = gun:GetAttribute(WeaponConstants.UNANCHORED_IMPULSE_FORCE_ATTRIBUTE) or 0
	if force ~= 0 then
		for index, rayResult in rayResults do
			if rayResult.taggedHumanoid then
				continue
			end

			if rayResult.instance and rayResult.instance:IsA("BasePart") and not rayResult.instance.Anchored then
				local direction = rayDirections[index]
				local impulse = direction * force
				rayResult.instance:ApplyImpulseAtPosition(impulse, rayResult.position)
			end
		end
	end

	-- Replicate shot to other players
	for _, otherPlayer in Players:GetPlayers() do
		if otherPlayer == player then
			continue
		end

		replicateShotRemote:FireClient(otherPlayer, gun, origin.Position, rayResults)
	end
end

local function onReloadEvent(player: Player, gun: any)
	if typeof(gun) ~= "Instance" or not gun:IsA("Tool") then
		return
	end

	if not validateReload(player, gun) then
		return
	end

	local reloadTime = gun:GetAttribute(WeaponConstants.RELOAD_TIME_ATTRIBUTE)
	local magazineSize = gun:GetAttribute(WeaponConstants.MAGAZINE_SIZE_ATTRIBUTE)

	local character = player.Character
	gun:SetAttribute(WeaponConstants.RELOADING_ATTRIBUTE, true)

	local reloadTask
	local ancestryChangedConnection

	reloadTask = task.delay(reloadTime, function()
		gun:SetAttribute(WeaponConstants.AMMO_ATTRIBUTE, magazineSize)
		gun:SetAttribute(WeaponConstants.RELOADING_ATTRIBUTE, false)
		ancestryChangedConnection:Disconnect()
	end)

	ancestryChangedConnection = gun.AncestryChanged:Connect(function()
		if gun.Parent ~= character then
			gun:SetAttribute(WeaponConstants.RELOADING_ATTRIBUTE, false)

			task.cancel(reloadTask)
			ancestryChangedConnection:Disconnect()
		end
	end)
end

--=============================================================================
-- Gun tool setup (config attributes + initial ammo)
--=============================================================================

local function setupGun(gun: Tool)
	WeaponConfigs.applyTo(gun)

	if gun:GetAttribute(WeaponConstants.AMMO_ATTRIBUTE) == nil then
		gun:SetAttribute(WeaponConstants.AMMO_ATTRIBUTE, gun:GetAttribute(WeaponConstants.MAGAZINE_SIZE_ATTRIBUTE) or 0)
	end
	if gun:GetAttribute(WeaponConstants.RELOADING_ATTRIBUTE) == nil then
		gun:SetAttribute(WeaponConstants.RELOADING_ATTRIBUTE, false)
	end
end

--=============================================================================
-- Raycast-exclusion tagging (character/accessory/tool parts)
--=============================================================================

local function tagPart(part: BasePart)
	-- Tag all character parts as NON_STATIC, so they can be ignored when casting against static geometry
	part:AddTag(WeaponConstants.NON_STATIC_TAG)

	-- Tag parts in accessories and tools with RAY_EXCLUDE_TAG so they can be ignored by raycasts
	local accessory = part:FindFirstAncestorWhichIsA("Accessory")
	local tool = part:FindFirstAncestorWhichIsA("Tool")
	if accessory or tool then
		part:AddTag(WeaponConstants.RAY_EXCLUDE_TAG)
	end
end

local function onCharacterAdded(character: Model)
	character.DescendantAdded:Connect(function(instance: Instance)
		if instance:IsA("BasePart") then
			tagPart(instance)
		end
	end)

	for _, instance in character:GetDescendants() do
		if instance:IsA("BasePart") then
			tagPart(instance)
		end
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(onCharacterAdded)

	if player.Character then
		onCharacterAdded(player.Character)
	end
end

function GunService.Start()
	replicateShotRemote = Net:UnreliableRemoteEvent(RemoteConfig.Weapon.ReplicateShot.Name)
	Net:Connect(RemoteConfig.Weapon.Shoot.Name, onShootEvent)
	Net:Connect(RemoteConfig.Weapon.Reload.Name, onReloadEvent)

	for _, gun in CollectionService:GetTagged(Tags.Gun) do
		setupGun(gun)
	end
	CollectionService:GetInstanceAddedSignal(Tags.Gun):Connect(setupGun)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
end

return GunService
