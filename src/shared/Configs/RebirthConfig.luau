local RebirthConfig = {}

export type Tier = {
	RequiredLevel: number,
	Multiplier: number,
}

-- Tiers[N] = requirement/reward for performing the Nth rebirth (going from
-- Rebirths = N-1 to Rebirths = N requires reaching RequiredLevel). Add more
-- entries to extend progression - no other code needs to change.
-- RequiredLevel ramps gently at first (5/10/15/20) then accelerates, topping
-- out at Level 400 for the 20th (max) rebirth - comfortably past the Level
-- 150 shrink-scale cap (ShrinkConfig), but far short of what the uncapped
-- Shrink-stat->Level curve (LevelConfig) could otherwise demand.
-- Placeholder balance curve (tunable).
RebirthConfig.Tiers = {
	[1] = { RequiredLevel = 5, Multiplier = 2 },
	[2] = { RequiredLevel = 10, Multiplier = 3 },
	[3] = { RequiredLevel = 15, Multiplier = 4 },
	[4] = { RequiredLevel = 20, Multiplier = 5 },
	[5] = { RequiredLevel = 30, Multiplier = 6 },
	[6] = { RequiredLevel = 40, Multiplier = 8 },
	[7] = { RequiredLevel = 55, Multiplier = 10 },
	[8] = { RequiredLevel = 70, Multiplier = 12 },
	[9] = { RequiredLevel = 90, Multiplier = 15 },
	[10] = { RequiredLevel = 110, Multiplier = 18 },
	[11] = { RequiredLevel = 135, Multiplier = 22 },
	[12] = { RequiredLevel = 160, Multiplier = 26 },
	[13] = { RequiredLevel = 190, Multiplier = 32 },
	[14] = { RequiredLevel = 220, Multiplier = 38 },
	[15] = { RequiredLevel = 255, Multiplier = 45 },
	[16] = { RequiredLevel = 290, Multiplier = 55 },
	[17] = { RequiredLevel = 325, Multiplier = 65 },
	[18] = { RequiredLevel = 355, Multiplier = 80 },
	[19] = { RequiredLevel = 380, Multiplier = 95 },
	[20] = { RequiredLevel = 400, Multiplier = 115 },
} :: { [number]: Tier }

local maxDefinedTier = 0
for tierNumber in RebirthConfig.Tiers do
	maxDefinedTier = math.max(maxDefinedTier, tierNumber)
end

-- Returns the requirement/reward for a given rebirth number. Beyond the
-- highest defined tier, the last tier is reused indefinitely (multiplier
-- growth plateaus, but rebirthing never gets blocked).
function RebirthConfig.GetTier(rebirthNumber: number): Tier?
	return RebirthConfig.Tiers[rebirthNumber] or RebirthConfig.Tiers[maxDefinedTier]
end

-- The multiplier a player currently benefits from, based on completed rebirths.
function RebirthConfig.GetMultiplierForRebirths(rebirths: number): number
	if rebirths <= 0 then return 1 end
	local tier = RebirthConfig.GetTier(rebirths)
	return tier and tier.Multiplier or 1
end

return RebirthConfig
