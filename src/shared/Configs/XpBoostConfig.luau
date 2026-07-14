export type BoostEntry = {
	DurationMinutes: number,
}

-- Each entry drives one auto-generated tier in the Shop's x2 Speed section
-- (see ShopController.Start, which clones a template frame once per entry)
-- and must have a matching MonetizationConfig.DevProducts.XpBoost[tostring(DurationMinutes)]
-- entry for its Robux price.
return {
	{ DurationMinutes = 10 },
	{ DurationMinutes = 30 },
	{ DurationMinutes = 60 },
}
