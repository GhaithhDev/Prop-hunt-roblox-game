local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local MonetizationConfig = require(ReplicatedStorage.Shared.Configs.MonetizationConfig)
local MonetizationService = require(ServerScriptService.Server.Monetization.MonetizationService)

local WinsMultiplierService = {}

function WinsMultiplierService.HasDoubleWins(player: Player): boolean
	return MonetizationService.OwnsPass(player, "WinsMultiplier", "Double")
end

-- Exposed as a public function (not just an inline Triggered closure) so it's
-- directly callable from execute_luau for testing without real client input.
function WinsMultiplierService.HandlePromptTriggered(player: Player)
	if WinsMultiplierService.HasDoubleWins(player) then
		Net:RemoteEvent("Notify"):FireClient(player, "error", "You already own 2x Wins!")
		return
	end

	local productId = MonetizationConfig.GamePasses.WinsMultiplier and MonetizationConfig.GamePasses.WinsMultiplier.Double
	if not productId or productId == 0 then
		Net:RemoteEvent("Notify"):FireClient(player, "error", "That isn't purchasable yet.")
		return
	end

	MonetizationService.PromptPurchaseById(player, productId)
end

function WinsMultiplierService.Start()
	local prompt = workspace.Functional.Prompts["2xWin"].ProximityPrompt
	prompt.Triggered:Connect(WinsMultiplierService.HandlePromptTriggered)
end

return WinsMultiplierService
