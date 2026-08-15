--[[
	WeaponConstants

	Central attribute names and tunable constants for the gun system. Ported from
	Roblox's official FPS ("Blaster") template and adapted for Prop Hunt.

	Any Tool tagged Tags.Gun and given these attributes becomes a working gun - see
	WeaponConfigs.luau for the full per-gun setup contract.
]]

local WeaponConstants = {}

--//Raycast tags
WeaponConstants.RAY_EXCLUDE_TAG = "RayExclude"
WeaponConstants.NON_STATIC_TAG = "NonStatic"

--//Fire modes
WeaponConstants.FIRE_MODE = {
	SEMI = "Semi",
	AUTO = "Auto",
}

--//Attribute names (set these on the gun Tool, directly or via WeaponConfigs)
WeaponConstants.AMMO_ATTRIBUTE = "_ammo"
WeaponConstants.RELOADING_ATTRIBUTE = "_reloading"
WeaponConstants.DAMAGE_ATTRIBUTE = "damage"
WeaponConstants.FIRE_MODE_ATTRIBUTE = "fireMode"
WeaponConstants.MAGAZINE_SIZE_ATTRIBUTE = "magazineSize"
WeaponConstants.RANGE_ATTRIBUTE = "range"
WeaponConstants.RATE_OF_FIRE_ATTRIBUTE = "rateOfFire"
WeaponConstants.RELOAD_TIME_ATTRIBUTE = "reloadTime"
WeaponConstants.RAYS_PER_SHOT_ATTRIBUTE = "raysPerShot"
WeaponConstants.RAY_RADIUS_ATTRIBUTE = "rayRadius"
WeaponConstants.SPREAD_ATTRIBUTE = "spread"
WeaponConstants.VIEW_MODEL_ATTRIBUTE = "viewModel"
WeaponConstants.RECOIL_MIN_ATTRIBUTE = "recoilMin"
WeaponConstants.RECOIL_MAX_ATTRIBUTE = "recoilMax"
WeaponConstants.UNANCHORED_IMPULSE_FORCE_ATTRIBUTE = "unanchoredImpulseForce"
WeaponConstants.AIM_ASSIST_RANGE_ATTRIBUTE = "aimAssistRange"
WeaponConstants.AIM_ASSIST_FOV_ATTRIBUTE = "aimAssistFov"
WeaponConstants.AIM_ASSIST_FRICTION_STRENGTH_ATTRIBUTE = "aimAssistFrictionStrength"
WeaponConstants.AIM_ASSIST_TRACKING_STRENGTH_ATTRIBUTE = "aimAssistTrackingStrength"
WeaponConstants.AIM_ASSIST_CENTERING_STRENGTH_ATTRIBUTE = "aimAssistCenteringStrength"

--//Input
WeaponConstants.KEYBOARD_RELOAD_KEY_CODE = Enum.KeyCode.R
WeaponConstants.GAMEPAD_RELOAD_KEY_CODE = Enum.KeyCode.ButtonX

--//UI scaling (matches the default touch control breakpoint)
WeaponConstants.UI_SMALL_SCREEN_THRESHOLD = 500
WeaponConstants.UI_SMALL_SCREEN_SCALE = 0.6

WeaponConstants.HITMARKER_SOUND_DELAY = 0.1

--//Aim assist
WeaponConstants.AIM_ASSIST_BIND_NAME_START = "GunAimAssistStart"
WeaponConstants.AIM_ASSIST_BIND_NAME_APPLY = "GunAimAssistApply"
WeaponConstants.AIM_ASSIST_TARGET_TAG = "GunAimAssistTarget"
WeaponConstants.AIM_ASSIST_DEADZONE = 0.1
WeaponConstants.AIM_ASSIST_INACTIVITY = 0.1
WeaponConstants.AIM_ASSIST_MIN_RANGE = 10

--//View model
WeaponConstants.VIEW_MODEL_BIND_NAME = "GunViewModel"
WeaponConstants.VIEW_MODEL_OFFSET = CFrame.new(0.9, -1.3, -1.3)
WeaponConstants.VIEW_MODEL_BOBBING_SPEED = 0.4
WeaponConstants.VIEW_MODEL_BOBBING_AMOUNT = 0.05
WeaponConstants.VIEW_MODEL_BOBBING_TRANSITION_SPEED = 10
WeaponConstants.VIEW_MODEL_RELOAD_FADE_TIME = 0.1

--//Recoil
WeaponConstants.RECOIL_BIND_NAME = "GunRecoiler"
WeaponConstants.RECOIL_STOP_SPEED = 10
WeaponConstants.RECOIL_ZOOM_RETURN_SPEED = 20
WeaponConstants.RECOIL_DEFAULT_FOV = 70

--//VFX
WeaponConstants.LASER_BEAM_VISUAL_SPEED = 200

return WeaponConstants
