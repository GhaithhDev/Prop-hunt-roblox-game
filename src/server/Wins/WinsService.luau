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
local MonetizationUtils = require(ReplicatedStorage.Shared.Utils.MonetizationUtils)
local MonetizationService = require(ServerScriptService.Server.Monetization.MonetizationService)

local DEBOUNCE_TIME = 1

local WIN_PART_BILLBOARD_TEMPLATE = ReplicatedStorage.Shared.Assets.Billbaords.WinPart
local ROBUX_WIN_BILLBOARD_TEMPLATE = ReplicatedStorage.Shared.Assets.Billbaords.RobuxWins


local SPAWN_UP_OFFSET = Vector3.new(0, 5, 0) -- lift off the spawn pad so the character doesn't land clipped into it

local WinsService = {}

local debounce = {}

-- World1's spawn stays at the original unprefixed path; World2/3 live under
-- their own top-level world root folders, same convention as AutoWinsStart/
-- Decorations.Stages (see AutoWinsService.GetAutoWinsStartPart/GetStagesRoot).
local function GetSpawnPosition(world: number?): Vector3?
	local worldNum = (world and tonumber(world)) or 1
	local functionalRoot = workspace.Functional
	if worldNum ~= 1 then
		local worldRoot = workspace:FindFirstChild("World" .. worldNum)
		functionalRoot = (worldRoot and worldRoot:FindFirstChild("Functional")) or workspace.Functional
	end

	local spawnLocation = functionalRoot:FindFirstChild("SpawnLocation")
	if not spawnLocation then
		warn("WinsService: no SpawnLocation found for world " .. tostring(worldNum))
		return nil
	end

	return spawnLocation.Position + SPAWN_UP_OFFSET
end

-- x2Win is a single shared ProductId across every stage (unlike SkipToStage's
-- per-stage IDs), so ProcessReceipt alone can't tell which stage a given
-- purchase was for - remember it per-player between the prompt and the
-- purchase confirming (same convention as TeleportService.pendingRevive).
local pendingX2Win: { [Player]: { stage: number, world: number? } } = {}

local function InitWinPart(part)
	local stage = WinsConfig.GetWinsForStage(part:GetAttribute("Stage"), part:GetAttribute("World"))
	if not stage then
		warn("Stage attribute is not set for ", part)
		return
	end

	local billboardGui = part:FindFirstChild("BillboardGui")
	if not billboardGui then
		billboardGui = part:GetAttribute("RequireRobux") and ROBUX_WIN_BILLBOARD_TEMPLATE:Clone()
			or WIN_PART_BILLBOARD_TEMPLATE:Clone()
		billboardGui.Name = "BillboardGui"

		if part:GetAttribute("RequireRobux") then
			local price = MonetizationUtils.GetProductPriceInRobux(MonetizationConfig.DevProducts.x2Win)
			if price then
				billboardGui.RobuxPrice.Text = NumberFormat.Format(price)
			else
				warn("MonetizationConfig.DevProducts.x2Wins isn't setup yet")
			end
		end

		billboardGui.Parent = part
	end

	local displayedWins = part:GetAttribute("RequireRobux") and stage * 2 or stage
	billboardGui.AmountofWins.Text = "+" .. NumberFormat.Format(displayedWins) .. " Wins"
end

-- Public entry point for non-stage sources of Wins (e.g. UFOEventService's
-- abduction reward) that still want the same multiplier stack a stage win
-- gets (WinsMultiplier gamepass, Admin Wins multiplier) - just without the
-- stage-pad-specific spawn teleport.
function WinsService.GrantWins(player: Player, amount: number)
	if WinsMultiplierService.HasDoubleWins(player) then
		amount *= 2
	end
	amount = math.floor(amount * AdminService.GetWinsMultiplier())
	DataManager.Add(player, "Wins", amount)
	PressXpService.RecheckEquippedOption(player)
end

-- Shared by both the immediate-grant path and the x2Win purchase-confirmed
-- path so they always apply the same multiplier stack.
local function grantStageWins(player: Player, stage: number, world: number?, extraMultiplier: number?)
	local winsAmount = WinsConfig.GetWinsForStage(stage, world)
	if not winsAmount then
		warn("WinsService: no WinsConfig entry for stage " .. tostring(stage) .. " world " .. tostring(world))
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

	local character = player.Character
	if character then
		local playerWorld = DataManager.Get(player, "World") or 1
		local spawnPosition = GetSpawnPosition(playerWorld)
		if spawnPosition then
			character:PivotTo(CFrame.new(spawnPosition))
		end
	end
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
	local world = part:GetAttribute("World")

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

		pendingX2Win[player] = { stage = stage, world = world }
		MonetizationService.PromptPurchaseById(player, x2WinProductId)
		return
	end

	grantStageWins(player, stage, world)
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
			local pending = pendingX2Win[player]
			pendingX2Win[player] = nil

			if not pending then
				warn(`WinsService: x2Win purchase confirmed for {player.Name} but no pendingX2Win - skipping grant`)
				return
			end

			grantStageWins(player, pending.stage, pending.world, 2)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		pendingX2Win[player] = nil
	end)
end

return WinsService
