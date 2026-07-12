local AurasConfig = {}

export type Item = {
	Name: string,
	WinsCost: number,
	Multiplier: number,
	Color: Color3,
}

-- Keyed by name - must match the MonetizationConfig.GamePasses.Auras key
-- exactly (ownership is tracked via MonetizationService.OwnsPass(player,
-- "Auras", id), stored under an "Auras_<id>" key). Placeholder Wins/
-- multiplier numbers - tune freely, any number of entries works.
AurasConfig.Items = {
	Spark = { Name = "Spark Aura", WinsCost = 400, Multiplier = 1.1, Color = Color3.fromRGB(255, 230, 80) },
	Glow = { Name = "Glow Aura", WinsCost = 1500, Multiplier = 1.25, Color = Color3.fromRGB(120, 255, 200) },
	Storm = { Name = "Storm Aura", WinsCost = 6000, Multiplier = 1.5, Color = Color3.fromRGB(150, 150, 255) },
	Radiant = { Name = "Radiant Aura", WinsCost = 25000, Multiplier = 2, Color = Color3.fromRGB(255, 255, 255) },
} :: { [string]: Item }

-- Returns 1 for "" (unequipped) or an unknown id.
function AurasConfig.GetMultiplierForEquipped(id: string): number
	local item = id ~= "" and AurasConfig.Items[id]
	return item and item.Multiplier or 1
end

return AurasConfig
