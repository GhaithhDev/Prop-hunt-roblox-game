local TreadmillConfig = {}

-- How often (seconds) a standing player is granted XP while on any treadmill.
TreadmillConfig.XpTickInterval = 0.05

-- Studs added on top of a treadmill's real GetBoundingBox() height when detecting
-- standing characters, to comfortably catch the character's root above the tread's
-- visual center.
TreadmillConfig.StandHitboxVerticalPadding = 4

-- Studs of padding added when checking a candidate spawn position's bounding box
-- against existing treadmills' bounding boxes.
TreadmillConfig.SpawnOverlapMargin = 2

-- Spawn "pop" animation.
TreadmillConfig.PopAnimationDuration = 0.35
TreadmillConfig.PopStartScale = 0.05

return TreadmillConfig
