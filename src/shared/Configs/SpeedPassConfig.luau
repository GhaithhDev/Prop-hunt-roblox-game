local SpeedPassConfig = {}

export type Tier = { Id: string, Multiplier: number }

-- Order matters here (gating sequence) - MonetizationConfig.GamePasses itself
-- is unordered, so this is the one source of truth for tier sequence. Id
-- must match the MonetizationConfig.GamePasses.SpeedPass key exactly.
SpeedPassConfig.Tiers = {
	{ Id = "Tier2", Multiplier = 2 },
	{ Id = "Tier4", Multiplier = 4 },
	{ Id = "Tier8", Multiplier = 8 },
	{ Id = "Tier16", Multiplier = 16 },
} :: { Tier }

-- owned: { [tierId]: boolean }, e.g. GetShopStatus()'s SpeedPass field
-- client-side, or { [tierId] = MonetizationService.OwnsPass(...) } server-side.
function SpeedPassConfig.GetNextTier(owned: { [string]: boolean }): Tier?
	for _, tier in SpeedPassConfig.Tiers do
		if not owned[tier.Id] then
			return tier
		end
	end
	return nil
end

function SpeedPassConfig.GetMultiplierForOwned(owned: { [string]: boolean }): number
	local multiplier = 1
	for _, tier in SpeedPassConfig.Tiers do
		if owned[tier.Id] then
			multiplier = tier.Multiplier
		else
			break -- stop at first unowned tier - defends against out-of-order ownership anomalies
		end
	end
	return multiplier
end

return SpeedPassConfig
