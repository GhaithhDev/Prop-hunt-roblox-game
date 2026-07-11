local AurasConfig = {}

export type Item = {
	Name: string,
	WinsCost: number,
	Multiplier: number,
	Color: Color3,
}

-- Keyed by PassId - also used as the DataManager.Owns(player, "OwnedPasses", id)
-- key, same category real Passes already use. Placeholder Wins/multiplier
-- numbers - tune freely, any number of entries works.
AurasConfig.Items = {
	Aura_Spark = { Name = "Spark Aura", WinsCost = 400, Multiplier = 1.1, Color = Color3.fromRGB(255, 230, 80) },
	Aura_Glow = { Name = "Glow Aura", WinsCost = 1500, Multiplier = 1.25, Color = Color3.fromRGB(120, 255, 200) },
	Aura_Storm = { Name = "Storm Aura", WinsCost = 6000, Multiplier = 1.5, Color = Color3.fromRGB(150, 150, 255) },
	Aura_Radiant = { Name = "Radiant Aura", WinsCost = 25000, Multiplier = 2, Color = Color3.fromRGB(255, 255, 255) },
} :: { [string]: Item }

-- Returns 1 for "" (unequipped) or an unknown id.
function AurasConfig.GetMultiplierForEquipped(id: string): number
	local item = id ~= "" and AurasConfig.Items[id]
	return item and item.Multiplier or 1
end

return AurasConfig
