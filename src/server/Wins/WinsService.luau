local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local DataManager = require(ServerScriptService.Server.Data.Manager)
local Tags = require(ReplicatedStorage.Shared.Configs.Tags)
local WinsConfig = require(ReplicatedStorage.Shared.Configs.WinsConfig)
local Net = require(ReplicatedStorage.Shared.Packages.Net)
local NumberFormat = require(ReplicatedStorage.Shared.Packages.NumberFormat)
local PressXpService = require(ServerScriptService.Server.PressXp.PressXpService)
local WinsMultiplierService = require(ServerScriptService.Server.WinsMultiplier.WinsMultiplierService)
local AdminService = require(ServerScriptService.Server.Admin.AdminService)
local MonetizationConfig = require(ReplicatedStorage.Shared.Configs.MonetizationConfig)
local MonetizationService = require(ServerScriptService.Server.Monetization.MonetizationService)

local DEBOUNCE_TIME = 1

local WIN_PART_BILLBOARD_TEMPLATE = ReplicatedStorage.Shared.Assets.Billbaords.WinPart

local WinsService = {}

local debounce = {}

-- x2Win is a single shared ProductId across every stage (unlike SkipToStage's
-- per-stage IDs), so ProcessReceipt alone can't tell which stage a given
-- purchase was for - remember it per-player between the prompt and the
-- purchase confirming (same convention as TeleportService.pendingRevive).
local pendingX2Win: { [Player]: number } = {}

local function InitWinPart(part)
	local stage = WinsConfig.GetWinsForStage(part:GetAttribute("Stage"))
	if not stage then
		warn("Stage attribute is not set for ", part)
		return
	end

	local billboardGui = part:FindFirstChild("BillboardGui")
	if not billboardGui then
		billboardGui = WIN_PART_BILLBOARD_TEMPLATE:Clone()
		billboardGui.Name = "BillboardGui"
		billboardGui.Parent = part
	end

	local displayedWins = part:GetAttribute("RequireRobux") and stage * 2 or stage
	billboardGui.AmountofWins.Text = "+" .. NumberFormat.Format(displayedWins) .. " Wins"
end

-- Shared by both the immediate-grant path and the x2Win purchase-confirmed
-- path so they always apply the same multiplier stack.
local function grantStageWins(player: Player, stage: number, extraMultiplier: number?)
	local winsAmount = WinsConfig.GetWinsForStage(stage)
	if not winsAmount then
		warn("WinsService: no WinsConfig entry for stage " .. tostring(stage))
		return
	end

	if WinsMultiplierService.HasDoubleWins(player) then
		winsAmount *= 2
	end

	if extraMultiplier then
		winsAmount *= extraMultiplier
	end

	-- Admin multiplier can be a non-whole number (arbitrary TextBox input),
	-- unlike the flat multipliers above - floor to keep Wins a clean integer.
	winsAmount = math.floor(winsAmount * AdminService.GetWinsMultiplier())

	DataManager.Add(player, "Wins", winsAmount)
	PressXpService.RecheckEquippedOption(player)

	-- Teleporting back to spawn is done client-side (see WinsTeleportController) -
	-- the client owns physics simulation of its own network-owned character, so
	-- pivoting it here on the server fights that simulation instead of just
	-- moving it.
	Net:RemoteEvent("WinAwarded"):FireClient(player)
end

local function OnWinHitboxTouched(part, hit)
	local character = hit.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player then return end

	if debounce[player] then return end
	debounce[player] = true
	task.delay(DEBOUNCE_TIME, function()
		debounce[player] = nil
	end)

	local stage = part:GetAttribute("Stage")

	if part:GetAttribute("RequireRobux") then
		local x2WinProductId = MonetizationConfig.DevProducts.x2Win
		if not x2WinProductId or x2WinProductId == 0 then
			warn("WinsService: DevProducts.x2Win has a placeholder ProductId (0) - replace it in MonetizationConfig before shipping")
			Net:RemoteEvent("Notify"):FireClient(player, "error", "This isn't available yet!")
			return
		end

		if pendingX2Win[player] then
			-- A purchase is already in flight for this player - ignore repeated
			-- Touched firings while they stand in the hitbox.
			return
		end

		pendingX2Win[player] = stage
		MonetizationService.PromptPurchaseById(player, x2WinProductId)
		return
	end

	grantStageWins(player, stage)
end

function WinsService.Start()
	for _, part in CollectionService:GetTagged(Tags.WIN_PART) do
		InitWinPart(part)
		part.Touched:Connect(function(hit)
			OnWinHitboxTouched(part, hit)
		end)
	end

	local x2WinProductId = MonetizationConfig.DevProducts.x2Win
	if x2WinProductId and x2WinProductId ~= 0 then
		MonetizationService.RegisterConsumable(x2WinProductId, function(player: Player)
			local stage = pendingX2Win[player]
			pendingX2Win[player] = nil

			if not stage then
				warn(`WinsService: x2Win purchase confirmed for {player.Name} but no pendingX2Win - skipping grant`)
				return
			end

			grantStageWins(player, stage, 2)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		pendingX2Win[player] = nil
	end)
end

return WinsService
