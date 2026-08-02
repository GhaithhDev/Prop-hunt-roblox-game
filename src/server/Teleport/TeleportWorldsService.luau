--//Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataManger = require(ServerScriptService.Server.Data.Manager)

--// Pacakges
local RemoteConfig = require(ReplicatedStorage.Shared.Configs.RemoteConfig)
local Net = require(ReplicatedStorage.Shared.Packages.Net)

--//Configs
local TeleportWorldsConfig = require(ReplicatedStorage.Shared.Configs.TeleportWorldsConfig)

--/Cache
local TeleportWorldsService = {}

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
    DataManger.YieldUntilLoadedOrReleased(player)
    local playerData = DataManger.GetData(player)
    local playerWorld = playerData.World
    if worldNum == playerWorld then
        Net:RemoteEvent("Notify"):FireClient(player, "error", `You are already in world {worldNum}!`)
        return false
    end
    local playerLevel = playerData.Level
    local levelRequirement = TeleportWorldsConfig.LevelRequirement[worldNum]
    if playerLevel < levelRequirement then
        Net:RemoteEvent("Notify"):FireClient(player, "error", `You need to be level {levelRequirement} to teleport to world {worldNum}!`)
        return false
    end
    local teleportPart = workspace.Functional.WorldsTeleportPositions:FindFirstChild(tostring(worldNum))
    if not teleportPart or not teleportPart:IsA("BasePart") then
        warn("Invalid teleport part for world " .. worldNum)
        return false
    end
    Net:RemoteEvent(RemoteConfig.UIEffects.FlashWhiteScreen.Name):FireClient(player,6)
    DataManger.Set(player,"World",worldNum)
    character:MoveTo(teleportPart.Position)
    return true
end

function TeleportWorldsService.Start(Services)
    DataManger = Services.Manager
    Net:Connect(RemoteConfig.Teleport.RequestTeleportToWorld.Name, ValidateTeleportToWorld)
end

return TeleportWorldsService