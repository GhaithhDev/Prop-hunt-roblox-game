local TrailsConfig = {}

export type Item = {
	Name: string,
	WinsCost: number,
	Multiplier: number,
	WalkSpeed: number,
	Color: Color3,
}

-- Keyed by name - must match the MonetizationConfig.GamePasses.Trails key
-- exactly (ownership is tracked via MonetizationService.OwnsPass(player,
-- "Trails", id), stored under a "Trails_<id>" key) AND the
-- ReplicatedStorage.Shared.Assets.Trails folder name exactly (equip visuals
-- are looked up by this same id). Multipliers extracted from the Inventory
-- frame; WinsCost is a fresh escalating placeholder progression (nothing
-- meaningful to extract - the UI's price labels were uniform placeholders) -
-- tune freely, any number of entries works.
TrailsConfig.Items = {
	Green = { Name = "Green Trail", WinsCost = 300, Multiplier = 1.5, WalkSpeed = 30, Color = Color3.fromRGB(60, 220, 90) },
	Blue = { Name = "Blue Trail", WinsCost = 5000, Multiplier = 2, WalkSpeed = 35, Color = Color3.fromRGB(60, 140, 255) },
	Purple = { Name = "Purple Trail", WinsCost = 25000, Multiplier = 3, WalkSpeed = 40, Color = Color3.fromRGB(170, 80, 255) },
	Red = { Name = "Red Trail", WinsCost = 250000, Multiplier = 4, WalkSpeed = 45, Color = Color3.fromRGB(255, 60, 60) },
	Yellow = { Name = "Yellow Trail", WinsCost = 10_000_000, Multiplier = 5, WalkSpeed = 50, Color = Color3.fromRGB(255, 220, 60) },
} :: { [string]: Item }

-- Returns 1 for "" (unequipped) or an unknown id.
function TrailsConfig.GetMultiplierForEquipped(id: string): number
	local item = id ~= "" and TrailsConfig.Items[id]
	return item and item.Multiplier or 1
end

-- WalkSpeed granted by the equipped trail - this is the only system in the
-- game that touches Humanoid.WalkSpeed. Returns BaseWalkSpeed for ""
-- (unequipped) or an unknown id.
TrailsConfig.BaseWalkSpeed = 25

function TrailsConfig.GetWalkSpeedForEquipped(id: string): number
	local item = id ~= "" and TrailsConfig.Items[id]
	return item and item.WalkSpeed or TrailsConfig.BaseWalkSpeed
end

return TrailsConfig
