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
	[1] = { RequiredLevel = 10, Multiplier = 2 },
	[2] = { RequiredLevel = 20, Multiplier = 3 },
	[3] = { RequiredLevel = 40, Multiplier = 4 },
	[4] = { RequiredLevel = 60, Multiplier = 5 },
	[5] = { RequiredLevel = 80, Multiplier = 6 },
	[6] = { RequiredLevel = 100, Multiplier = 8 },
	[7] = { RequiredLevel = 120, Multiplier = 10 },
	[8] = { RequiredLevel = 140, Multiplier = 12 },
	[9] = { RequiredLevel = 160, Multiplier = 14 },
	[10] = { RequiredLevel = 180, Multiplier = 16 },
	[11] = { RequiredLevel = 200, Multiplier = 18 },
	[12] = { RequiredLevel = 225, Multiplier = 20 },
	[13] = { RequiredLevel = 250, Multiplier = 22 },
	[14] = { RequiredLevel = 275, Multiplier = 24 },
	[15] = { RequiredLevel = 300, Multiplier = 26 },
	[16] = { RequiredLevel = 350, Multiplier = 28 },
	[17] = { RequiredLevel = 400, Multiplier = 30 },
	[18] = { RequiredLevel = 450, Multiplier = 35 },
	[19] = { RequiredLevel = 500, Multiplier = 40 },
	[20] = { RequiredLevel = 600, Multiplier = 45 },
	[21] = { RequiredLevel = 700, Multiplier = 50 },
	[22] = { RequiredLevel = 800, Multiplier = 55 },
	[23] = { RequiredLevel = 900, Multiplier = 60 },
	[24] = { RequiredLevel = 1000, Multiplier = 65 },
	[25] = { RequiredLevel = 1100, Multiplier = 70 },
	[26] = { RequiredLevel = 1200, Multiplier = 75 },
	[27] = { RequiredLevel = 1300, Multiplier = 80 },
	[28] = { RequiredLevel = 1400, Multiplier = 85 },
	[29] = { RequiredLevel = 1500, Multiplier = 90 },
	[30] = { RequiredLevel = 1600, Multiplier = 95 },
	[31] = { RequiredLevel = 1700, Multiplier = 100 },
	[32] = { RequiredLevel = 1800, Multiplier = 105 },
	[33] = { RequiredLevel = 1900, Multiplier = 110 },
	[34] = { RequiredLevel = 2000, Multiplier = 115 },
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
