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
	print("triggered")
	if WinsMultiplierService.HasDoubleWins(player) then
		Net:RemoteEvent("Notify"):FireClient(player, "error", "You already own 2x Wins!")
		return
	end

	local productId = MonetizationConfig.GamePasses.WinsMultiplier
		and MonetizationConfig.GamePasses.WinsMultiplier.Double
	if not productId or productId == 0 then
		Net:RemoteEvent("Notify"):FireClient(player, "error", "That isn't purchasable yet.")
		return
	end

	MonetizationService.PromptPurchaseById(player, productId)
end

function WinsMultiplierService.Start()
	print("Ran")
	local function setupPrompt(prompt)
		print(prompt.Name)
		if prompt.Name == "2xWin" then
			print("hooked prompt",prompt)
			prompt.ProximityPrompt.Triggered:Connect(WinsMultiplierService.HandlePromptTriggered)
		end
	end
	for _, prompt in workspace.Functional.Prompts:GetChildren() do
		setupPrompt(prompt)
	end
	workspace.Functional.Prompts.ChildAdded:Connect(setupPrompt)
end

return WinsMultiplierService
