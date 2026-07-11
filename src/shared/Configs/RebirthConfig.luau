local RebirthConfig = {}

export type Tier = {
	RequiredLevel: number,
	Multiplier: number,
}

-- Tiers[N] = requirement/reward for performing the Nth rebirth (going from
-- Rebirths = N-1 to Rebirths = N requires reaching RequiredLevel). Add more
-- entries to extend progression - no other code needs to change.
RebirthConfig.Tiers = {
	[1] = { RequiredLevel = 1, Multiplier = 2 },
	[2] = { RequiredLevel = 100, Multiplier = 3 },
	[3] = { RequiredLevel = 150, Multiplier = 5 },
} :: { [number]: Tier }

-- PLACEHOLDER (0) - replace with a real Developer Product ID from the Creator
-- Dashboard. One shared product regardless of tier - "Skip Rebirth" always
-- means "pay to complete whichever rebirth is currently pending, right now."
RebirthConfig.SkipProductId = 0

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
