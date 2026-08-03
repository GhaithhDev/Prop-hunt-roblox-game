--//Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataManager = require(ServerScriptService.Server.Data.Manager)
local InventoryService = require(ServerScriptService.Server.Inventory.InventoryService)
local PressXpService = require(ServerScriptService.Server.PressXp.PressXpService)


--// Pacakges
local RemoteConfig = require(ReplicatedStorage.Shared.Configs.RemoteConfig)
local Net = require(ReplicatedStorage.Shared.Packages.Net)

--//Configs
local TeleportWorldsConfig = require(ReplicatedStorage.Shared.Configs.TeleportWorldsConfig)

--/Cache
local FailedToTeleportPlayers = {}
local TeleportWorldsService = {}

local function TeleportToWorld(character: Model, worldNum: number)
	local teleportPart = workspace.Functional.WorldsTeleportPositions:FindFirstChild(tostring(worldNum))
	if not teleportPart or not teleportPart:IsA("BasePart") then
		warn("Invalid teleport part for world " .. worldNum)
		return false
	end
	character:MoveTo(teleportPart.Position)
end

local function ValidateTeleportToWorld(player: Player, worldNum: number)
	if typeof(worldNum) ~= "number" or not TeleportWorldsConfig.LevelRequirement[worldNum] then
		player:Kick("Invalid world number type")
		return false
	end
	local character = player.Character
	if not character or not character:FindFirstChild("HumanoidRootPart") then
		Net:RemoteEvent("Notify"):FireClient(player, "error", "You must be alive to teleport to another world!")
		return false
	end
	DataManager.YieldUntilLoadedOrReleased(player)
	local playerData = DataManager.GetData(player)
	local playerWorld = playerData.World
	if worldNum == playerWorld then
		Net:RemoteEvent("Notify"):FireClient(player, "error", `You are already in world {worldNum}!`)
		return false
	end
	local playerLevel = playerData.Level
	local levelRequirement = TeleportWorldsConfig.LevelRequirement[worldNum]
	if playerLevel < levelRequirement then
		Net:RemoteEvent("Notify")
			:FireClient(player, "error", `You need to be level {levelRequirement} to teleport to world {worldNum}!`)
		return false
	end

	Net:RemoteEvent(RemoteConfig.UIEffects.FlashWhiteScreen.Name):FireClient(player, 6)
	DataManager.Set(player, "World", worldNum)
	PressXpService.RecheckEquippedOption(player)

    TeleportToWorld(character, worldNum)

	return true
end

local function OnCharacterAdded(player, character: Model)
	DataManager.YieldUntilLoadedOrReleased(player)
	if not player then
		return
	end
	local playerWorld = DataManager.Get(player, "World")
	local root = character:WaitForChild("HumanoidRootPart")
	if not root then
		warn("Data has loaded but root still didn't")
		FailedToTeleportPlayers[player] = true
		return
	end

    print("Teleporting player to world " .. playerWorld)
    TeleportToWorld(character, playerWorld)
    print("Applying speed")
    InventoryService.ApplyEquippedEffects(player)
end

local function OnPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		OnCharacterAdded(player, character)
	end)

	if player.Character then
		OnCharacterAdded(player, player.Character)
	end
end

local function LookForFailedTeleports()
    for player , failedToTeleport in pairs(FailedToTeleportPlayers) do
        if not failedToTeleport or not player then continue end
        local character = player.Character
        if not character then continue end
        FailedToTeleportPlayers[player] = nil
        OnCharacterAdded(player, character)
    end
end

function TeleportWorldsService.Start(Services)
	DataManager = Services.Manager
    InventoryService = Services.InventoryService

	Net:Connect(RemoteConfig.Teleport.RequestTeleportToWorld.Name, ValidateTeleportToWorld)

	for _, player in Players:GetPlayers() do
		OnPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(OnPlayerAdded)

    task.spawn(function()
        while task.wait(1) do
            LookForFailedTeleports()
        end
    end)
end

return TeleportWorldsService
