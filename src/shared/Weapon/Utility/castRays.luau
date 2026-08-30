local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WeaponConstants = require(ReplicatedStorage.Shared.Configs.WeaponConstants)
local Tags = require(ReplicatedStorage.Shared.Configs.Tags)
local canPlayerDamageHumanoid = require(script.Parent.canPlayerDamageHumanoid)

export type RayResult = {
	taggedHumanoid: Humanoid?,
	position: Vector3,
	normal: Vector3,
	instance: Instance?,
}

local function castRays(
	player: Player,
	position: Vector3,
	directions: { Vector3 },
	radius: number,
	staticOnly: boolean?
): { RayResult }
	local exclude = CollectionService:GetTagged(WeaponConstants.RAY_EXCLUDE_TAG)

	if staticOnly then
		local nonStatic = CollectionService:GetTagged(WeaponConstants.NON_STATIC_TAG)
		-- Append nonStatic to exclude
		table.move(nonStatic, 1, #nonStatic, #exclude + 1, exclude)
	end

	-- Always include the player's character in the exclude list
	if player.Character then
		table.insert(exclude, player.Character)
	end

	local collisionGroup = nil

	-- If the player is on a team, use that team's collision group to ensure the ray passes through
	-- characters and forcefields on that team.
	if player.Team and not player.Neutral then
		collisionGroup = player.Team.Name
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	params.FilterDescendantsInstances = exclude
	if collisionGroup then
		params.CollisionGroup = collisionGroup
	end

	local rayResults = {}

	for _, direction in directions do
		-- In order to provide a simple form of bullet magnetism, we use spherecasts with a small radius instead of raycasts.
		-- This allows closely grazing shots to register as hits, making guns feel a bit more accurate and improving the 'game feel'.
		local raycastResult = Workspace:Spherecast(position, radius, direction, params)
		local rayResult: RayResult = {
			position = position + direction,
			normal = direction.Unit,
		}

		if raycastResult then
			rayResult.position = raycastResult.Position
			rayResult.normal = raycastResult.Normal
			rayResult.instance = raycastResult.Instance

			-- Walk up ancestors (not just the immediate parent) so hits on nested
			-- parts - accessory handles, nested models, etc. - still resolve to
			-- the character's Humanoid. Also track whether the walk passed
			-- through the attached disguise prop, since a morphed character's
			-- real body parts stay briefly queryable during the post-damage
			-- health-tag reveal (Head.CanQuery has to be true for Roblox's own
			-- name/health tag to render) - a hit on the real body should still
			-- never deal damage, only a hit on the prop itself.
			local humanoid: Humanoid?
			local hitMorphProp = false
			local ancestor: Instance? = raycastResult.Instance
			while ancestor and ancestor ~= Workspace do
				if CollectionService:HasTag(ancestor, Tags.MorphProp) then
					hitMorphProp = true
				end
				humanoid = ancestor:FindFirstChildOfClass("Humanoid")
				if humanoid then
					break
				end
				ancestor = ancestor.Parent
			end

			if humanoid and canPlayerDamageHumanoid(player, humanoid) then
				local targetCharacter = humanoid.Parent
				local isMorphed = targetCharacter and targetCharacter:GetAttribute("IsMorph")
				if not isMorphed or hitMorphProp then
					rayResult.taggedHumanoid = humanoid
				end
			end
		end

		table.insert(rayResults, rayResult)
	end

	return rayResults
end

return castRays
