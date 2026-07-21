-- Source of truth for what percentage of a player's current "Shrink" stat
-- each option grants as a flat one-time bonus. Keyed identically to
-- MonetizationConfig.DevProducts.PlusPercentShrink so both sides cross-
-- reference the same option names.
return {
	FirstOption = 0.02, -- 2%
	SecondOption = 0.05, -- 5%
	ThirdOption = 0.12, -- 12%
}
