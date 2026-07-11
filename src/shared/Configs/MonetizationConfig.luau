--[[
	Registry of all monetized products.

	To add a new permanent one-time-unlock "Pass"
		1. Create a **Developer Product** on the Creator Dashboard.
		2. Add an entry below: PassId (must exactly match the `GamePassName`
		   attribute on any gating Instance), the real ProductId, Type = "Pass",
		   and a display Name.
	That's the only change needed - MonetizationService, ProcessReceipt, and
	PromptPurchase all key off this table generically.

	Consumables (repeatable, non-idempotent purchases) are NOT registered here -
	they're registered dynamically via MonetizationService.RegisterConsumable
	instead, since they don't fit this table's "own it or don't" Pass model.
]]

local TrailsConfig = require(script.Parent.TrailsConfig)
local AurasConfig = require(script.Parent.AurasConfig)

local MonetizationConfig = {}

export type ProductType = "Pass"

export type ProductEntry = {
	PassId: string,
	ProductId: number,
	Type: ProductType,
	Name: string,
}

-- PLACEHOLDER ProductIds (0) - replace with real Developer Product IDs from
-- the Creator Dashboard. MonetizationService.Start() warns loudly for any
-- entry still at 0, and PromptPurchase refuses to prompt for one.
MonetizationConfig.Products = {
	Gold = { PassId = "Gold", ProductId = 0, Type = "Pass", Name = "Gold Treadmill" },
	Diamond = { PassId = "Diamond", ProductId = 3609298248, Type = "Pass", Name = "Diamond Treadmill" },
	Zombie = { PassId = "Zombie", ProductId = 0, Type = "Pass", Name = "Zombie Treadmill" },
	Admin = { PassId = "Admin", ProductId = 0, Type = "Pass", Name = "Admin Treadmill" },
} :: { [string]: ProductEntry }

-- Trails/Auras are also permanent Passes (buy once, freely re-equip), so they
-- register here too - generated from TrailsConfig/AurasConfig so adding a new
-- trail/aura there is the only change needed, no manual duplication here.
for passId, item in TrailsConfig.Items do
	MonetizationConfig.Products[passId] = { PassId = passId, ProductId = 0, Type = "Pass", Name = item.Name }
end
for passId, item in AurasConfig.Items do
	MonetizationConfig.Products[passId] = { PassId = passId, ProductId = 0, Type = "Pass", Name = item.Name }
end

-- Built once at require-time: ProductId -> PassId (ProcessReceipt only gets a ProductId).
-- Guarded against ProductId == 0 so multiple still-placeholder entries don't collide.
MonetizationConfig.PassIdByProductId = {}
for passId, entry in MonetizationConfig.Products do
	if entry.ProductId ~= 0 then
		MonetizationConfig.PassIdByProductId[entry.ProductId] = passId
	end
end

return MonetizationConfig
