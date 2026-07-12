local TrailsConfig = {}

export type Item = {
	Name: string,
	WinsCost: number,
	Multiplier: number,
	Color: Color3,
}

-- Keyed by name - must match the MonetizationConfig.GamePasses.Trails key
-- exactly (ownership is tracked via MonetizationService.OwnsPass(player,
-- "Trails", id), stored under a "Trails_<id>" key). Placeholder Wins/
-- multiplier numbers - tune freely, any number of entries works.
TrailsConfig.Items = {
	Ember = { Name = "Ember Trail", WinsCost = 300, Multiplier = 1.1, Color = Color3.fromRGB(255, 120, 40) },
	Frost = { Name = "Frost Trail", WinsCost = 1200, Multiplier = 1.25, Color = Color3.fromRGB(120, 200, 255) },
	Toxic = { Name = "Toxic Trail", WinsCost = 5000, Multiplier = 1.5, Color = Color3.fromRGB(140, 255, 80) },
	Void = { Name = "Void Trail", WinsCost = 20000, Multiplier = 2, Color = Color3.fromRGB(180, 80, 255) },
} :: { [string]: Item }

-- Returns 1 for "" (unequipped) or an unknown id.
function TrailsConfig.GetMultiplierForEquipped(id: string): number
	local item = id ~= "" and TrailsConfig.Items[id]
	return item and item.Multiplier or 1
end

return TrailsConfig
