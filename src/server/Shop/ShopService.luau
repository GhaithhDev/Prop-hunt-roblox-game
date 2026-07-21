--[[
	ShopService

	Generic Shop-side Game Pass purchasing glue - kept separate from
	MonetizationService (which stays a reusable core, not Shop-specific).
	Currently only Treadmills are sold through the Shop this way, but
	RequestGamePassPurchase/GetShopStatus are written generically over
	MonetizationConfig.GamePasses categories, not hardcoded to Treadmills.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local MonetizationConfig = require(ReplicatedStorage.Shared.Configs.MonetizationConfig)
local MonetizationService = require(ServerScriptService.Server.Monetization.MonetizationService)

local ShopService = {}

local function getShopStatus(player: Player)
	local treadmills = {}
	for passId in MonetizationConfig.GamePasses.Treadmills do
		treadmills[passId] = MonetizationService.OwnsPass(player, "Treadmills", passId)
	end

	local shrinkPass = {}
	for passId in MonetizationConfig.GamePasses.ShrinkPass or {} do
		shrinkPass[passId] = MonetizationService.OwnsPass(player, "ShrinkPass", passId)
	end

	local keycapSounds = {}
	for passId in MonetizationConfig.GamePasses.KeycapSounds or {} do
		keycapSounds[passId] = MonetizationService.OwnsPass(player, "KeycapSounds", passId)
	end

	return {
		Treadmills = treadmills,
		ShrinkPass = shrinkPass,
		KeycapSounds = keycapSounds,
	}
end

local function onRequestGamePassPurchase(player: Player, category: string, passId: string)
	local categoryPasses = MonetizationConfig.GamePasses[category]
	local productId = categoryPasses and categoryPasses[passId]
	if not productId or productId == 0 then
		Net:RemoteEvent("Notify"):FireClient(player, "error", "That item isn't purchasable yet.")
		return
	end

	if MonetizationService.OwnsPass(player, category, passId) then
		Net:RemoteEvent("Notify"):FireClient(player, "error", `You already own {passId}!`)
		return
	end

	MonetizationService.PromptPurchaseById(player, productId)
end

function ShopService.Start()
	Net:Connect("RequestGamePassPurchase", onRequestGamePassPurchase)
	Net:Handle("GetShopStatus", getShopStatus)
end

return ShopService
