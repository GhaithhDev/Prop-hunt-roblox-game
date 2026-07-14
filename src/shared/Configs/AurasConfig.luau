local AurasConfig = {}

export type Item = {
	Name: string,
	WinsCost: number,
	Multiplier: number,
	Color: Color3,
}

-- Keyed by name - must match the MonetizationConfig.GamePasses.Auras key
-- exactly (ownership is tracked via MonetizationService.OwnsPass(player,
-- "Auras", id), stored under an "Auras_<id>" key) AND the
-- ReplicatedStorage.Shared.Assets.Auras folder name exactly (equip visuals
-- are looked up by this same id). Multipliers extracted from the Inventory
-- frame; WinsCost is a fresh escalating placeholder progression (nothing
-- meaningful to extract - the UI's price labels were uniform placeholders) -
-- tune freely, any number of entries works.
AurasConfig.Items = {
	Purple = { Name = "Purple Aura", WinsCost = 400, Multiplier = 1.2, Color = Color3.fromRGB(170, 80, 255) },
	Red = { Name = "Red Aura", WinsCost = 1500, Multiplier = 1.5, Color = Color3.fromRGB(255, 60, 60) },
	Yellow = { Name = "Yellow Aura", WinsCost = 6000, Multiplier = 2, Color = Color3.fromRGB(255, 220, 60) },
	Green = { Name = "Green Aura", WinsCost = 18000, Multiplier = 3, Color = Color3.fromRGB(60, 220, 90) },
	Blue = { Name = "Blue Aura", WinsCost = 45000, Multiplier = 4, Color = Color3.fromRGB(60, 140, 255) },
} :: { [string]: Item }

-- Returns 1 for "" (unequipped) or an unknown id.
function AurasConfig.GetMultiplierForEquipped(id: string): number
	local item = id ~= "" and AurasConfig.Items[id]
	return item and item.Multiplier or 1
end

return AurasConfig
