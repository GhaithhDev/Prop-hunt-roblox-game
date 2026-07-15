--//Services
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

--//Configs
local SIZE_MULTI_ATTRIBUTE = "KeycapSizeMulti"
local KeycapConfigs = require(ReplicatedStorage.Shared.Configs.KeycapConfigs)
local KeycapsConfigs = require(ReplicatedStorage.Shared.Configs.KeycapConfigs)
local Tags = require(ReplicatedStorage.Shared.Configs.Tags)

--//Packages
local SoundUtils = require(ReplicatedStorage.Shared.Packages.SoundUtils)

--//Cache
local lastSoundPlayTime = nil
local localDownKeycaps = {}
local serverDownKeycaps = {}
local restCFrames = {}
local activeTweens = {}
local PressKeycaps = {}

local function CancelTween(keycap)
    local tween = activeTweens[keycap]
    if tween then
        tween:Cancel()
    end
end

local function OnKeycapReleased(keycap)
    local restCFrame = restCFrames[keycap]
    if not restCFrame then return end

    CancelTween(keycap)
    local tween = TweenService:Create(
        keycap.PrimaryPart,
        TweenInfo.new(KeycapsConfigs.PressUpTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
        {CFrame = restCFrame}
    )
    activeTweens[keycap] = tween
    tween:Play()
end

local function OnKeycapPressed(keycap, player)
    if RunService:IsServer() then
        local LevelService = require(ServerScriptService.Server.Level.LevelService)
        LevelService.GrantClickXp(player)
        return
    end
    local restCFrame = restCFrames[keycap]
    if not restCFrame then
        restCFrame = keycap.PrimaryPart.CFrame
        restCFrames[keycap] = restCFrame
    end

    CancelTween(keycap)
    local pressedCFrame = restCFrame - restCFrame.UpVector * KeycapsConfigs.PressDepth * keycap:GetAttribute(SIZE_MULTI_ATTRIBUTE)
    local tween = TweenService:Create(
        keycap.PrimaryPart,
        TweenInfo.new(KeycapsConfigs.PressDownTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        {CFrame = pressedCFrame}
    )
    activeTweens[keycap] = tween
    tween:Play()

    if not lastSoundPlayTime or tick() - lastSoundPlayTime >= KeycapsConfigs.ClickSoundCooldown then
        -- Required inline (not at module top-level) to avoid a circular
        -- require: KeycapSoundController requires KeycapSoundConfig, not
        -- this module, but PressKeycaps is a dual-realm module and this
        -- path only exists client-side - same inline-require idiom
        -- XpPerPress.luau uses for its own live-service lookups.
        local KeycapSoundController = require(Players.LocalPlayer.PlayerScripts.Client.KeycapSound.KeycapSoundController)
        SoundUtils.PlayLocalSound(KeycapSoundController.GetActiveSound())
        lastSoundPlayTime = tick()
    end
end

local function ReleaseAll()
    for _, keycap in localDownKeycaps do
        OnKeycapReleased(keycap)
    end
    table.clear(localDownKeycaps)
end

local function CheckHitbox(player: Player,character)
    
    local params = OverlapParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character}

    local parts = workspace:GetPartBoundsInBox(character:GetPivot(), KeycapsConfigs.PressHitboxSize, params)
    local currentlyDown = {}

    if RunService:IsServer() then
        if not serverDownKeycaps[player.UserId] then
            serverDownKeycaps[player.UserId] = {}
        end
    end

    local downKeysTable = RunService:IsClient() and localDownKeycaps or serverDownKeycaps[player.UserId]

    for _, part in parts do
        local keycap = part.Parent
        if not keycap or not CollectionService:HasTag(keycap, Tags.KEYCAP) then continue end
        currentlyDown[keycap] = true
        
        if not table.find(downKeysTable, keycap) then
            table.insert(downKeysTable, keycap)
            OnKeycapPressed(keycap, player)
        end
    end

    for i = #downKeysTable, 1, -1 do
        local keycap = downKeysTable[i]
        if not currentlyDown[keycap] then
            local distanceToKeycap = (character:GetPivot().Position - keycap:GetPivot().Position).Magnitude
            if distanceToKeycap < KeycapConfigs.ReleaseKeyDistance then 
                continue 
            end
            if RunService:IsClient() then
                OnKeycapReleased(keycap)
            end
            table.remove(downKeysTable, i)
        end
    end
end

local function Update(dt)
    if RunService:IsClient() then
        local player = Players.LocalPlayer
        local character = player and player.Character
        if not character then 
            ReleaseAll()
            return
        end
        CheckHitbox(player,character)
    else

        local players = Players:GetPlayers()
        local ids = {}
        for _, _player in players do
            local character = _player.Character
            if character then
                CheckHitbox(_player, character)
            end
            table.insert(ids,_player.UserId)
        end

        for playerId , downKeys in pairs(serverDownKeycaps) do 
            if not table.find(ids,playerId) then
                serverDownKeycaps[playerId] = nil
                print("player with user id " .. playerId .. " doesn't exist any more, clearing his down keys entries")
            end
        end
    end
end

function PressKeycaps.Start()
    if RunService:IsClient() then
        RunService.RenderStepped:Connect(Update)
    else
        task.spawn(function()
            while task.wait(KeycapsConfigs.ServerTickRate) do
                Update()
            end
        end)
    end
end

return PressKeycaps