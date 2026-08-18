--[[
	WeaponConfigs

	Per-gun stat tables, keyed by the gun Tool's Name. GunService applies these as
	attributes to any Tool tagged Tags.Gun when it's created, so tuning numbers live
	here instead of being hand-set in Studio. Attributes already set directly on a
	Tool are left untouched - config values only fill in what's missing.

	=====================  ADDING A NEW GUN  =====================
	1. Build the gun Tool with a Handle (BasePart), tag it with the CollectionService
	   tag "Gun" (Tags.Gun), and add an entry below keyed by the Tool's Name.
	2. Optionally add Sounds/ (Equip, MagIn, MagOut, Shoot AudioPlayers/folders) and
	   Animations/ (Idle, Shoot, Reload, Equip Animation objects) folders inside the
	   Tool for third-person sound/animation - the gun still works without them.
	3. Build a viewmodel rig Model under
	   ReplicatedStorage.Shared.Weapon.ViewModels.<viewModel>, containing
	   Root/LeftArm/RightArm parts + Motor6Ds + an AnimationController + its own
	   Idle/Shoot/Reload/Equip animations + a MuzzleAttachment with FlashEmitter and
	   CircleEmitter children. Set this entry's viewModel field to match its name.
	================================================================
]]

local WeaponConstants = require(script.Parent.WeaponConstants)

local WeaponConfigs = {}

WeaponConfigs.Guns = {
	-- ["Example Gun"] = {
	-- 	[WeaponConstants.DAMAGE_ATTRIBUTE] = 10,
	-- 	[WeaponConstants.MAGAZINE_SIZE_ATTRIBUTE] = 30,
	-- 	[WeaponConstants.FIRE_MODE_ATTRIBUTE] = WeaponConstants.FIRE_MODE.AUTO,
	-- 	[WeaponConstants.RATE_OF_FIRE_ATTRIBUTE] = 600, -- rounds per minute
	-- 	[WeaponConstants.RELOAD_TIME_ATTRIBUTE] = 2,
	-- 	[WeaponConstants.RANGE_ATTRIBUTE] = 300,
	-- 	[WeaponConstants.RAYS_PER_SHOT_ATTRIBUTE] = 1,
	-- 	[WeaponConstants.RAY_RADIUS_ATTRIBUTE] = 0.2,
	-- 	[WeaponConstants.SPREAD_ATTRIBUTE] = 2, -- degrees
	-- 	[WeaponConstants.RECOIL_MIN_ATTRIBUTE] = Vector2.new(1, -1),
	-- 	[WeaponConstants.RECOIL_MAX_ATTRIBUTE] = Vector2.new(2, 1),
	-- 	[WeaponConstants.UNANCHORED_IMPULSE_FORCE_ATTRIBUTE] = 0,
	-- 	[WeaponConstants.VIEW_MODEL_ATTRIBUTE] = "ExampleGun",
	-- 	[WeaponConstants.SHOOT_SOUND_ATTRIBUTE] = "ExampleGunShot", -- name of a Sound under SoundService.SFX
	-- 	[WeaponConstants.AIM_ASSIST_RANGE_ATTRIBUTE] = 100,
	-- 	[WeaponConstants.AIM_ASSIST_FOV_ATTRIBUTE] = 8,
	-- 	[WeaponConstants.AIM_ASSIST_FRICTION_STRENGTH_ATTRIBUTE] = 0.5,
	-- 	[WeaponConstants.AIM_ASSIST_TRACKING_STRENGTH_ATTRIBUTE] = 0.3,
	-- 	[WeaponConstants.AIM_ASSIST_CENTERING_STRENGTH_ATTRIBUTE] = 0,
	-- },
}

function WeaponConfigs.applyTo(tool: Tool)
	local config = WeaponConfigs.Guns[tool.Name]
	if not config then
		return
	end

	for attribute, value in config do
		if tool:GetAttribute(attribute) == nil then
			tool:SetAttribute(attribute, value)
		end
	end
end

return WeaponConfigs
