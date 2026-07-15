local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local DataManager = require(ServerScriptService.Server.Data.Manager)
local Tags = require(ReplicatedStorage.Shared.Configs.Tags)
local WinsConfig = require(ReplicatedStorage.Shared.Configs.WinsConfig)
local Net = require(ReplicatedStorage.Shared.Packages.Net)
local PressXpService = require(ServerScriptService.Server.PressXp.PressXpService)
local WinsMultiplierService = require(ServerScriptService.Server.WinsMultiplier.WinsMultiplierService)
local AdminService = require(ServerScriptService.Server.Admin.AdminService)

local TELEPORT_OFFSET = Vector3.new(0, 3, 0)
local DEBOUNCE_TIME = 1

local WinsService = {}

local debounce = {}

local function InitWinPart(part)
	local stage = WinsConfig.GetWinsForStage(part:GetAttribute("Stage"))
	if not stage then
		warn("Stage attribute is not set for ", part)
		return
	end
	part.BillboardGui.AmountofWins.Text = "+" .. stage .. " Wins"
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
	local winsAmount = WinsConfig.GetWinsForStage(stage)
	if not winsAmount then
		warn("WinsService: no WinsConfig entry for stage " .. tostring(stage))
		return
	end

	if WinsMultiplierService.HasDoubleWins(player) then
		winsAmount *= 2
	end

	-- Admin multiplier can be a non-whole number (arbitrary TextBox input),
	-- unlike the flat x2 above - floor to keep Wins a clean integer.
	winsAmount = math.floor(winsAmount * AdminService.GetWinsMultiplier())

	DataManager.Add(player, "Wins", winsAmount)
	PressXpService.RecheckEquippedOption(player)

	local spawner = workspace.Functional.PlayerSpawners:GetChildren()[1]
	if spawner then
		character:PivotTo(spawner.CFrame + TELEPORT_OFFSET)
	end

	Net:RemoteEvent("WinAwarded"):FireClient(player)
end

function WinsService.Start()
	for _, part in CollectionService:GetTagged(Tags.WIN_PART) do
		InitWinPart(part)
		part.Touched:Connect(function(hit)
			OnWinHitboxTouched(part, hit)
		end)
	end
end

return WinsService
