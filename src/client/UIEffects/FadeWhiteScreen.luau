
--//Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

--//Configs
local RemoteConfig = require(game:GetService("ReplicatedStorage").Shared.Configs.RemoteConfig)
local FlashScreenConfig = require(game:GetService("ReplicatedStorage").Shared.Configs.UIEffects.FlashWhiteScreen)

--//Packages
local Net = require(game:GetService("ReplicatedStorage").Shared.Packages.Net)
local SoundUtils = require(game:GetService("ReplicatedStorage").Shared.Packages.SoundUtils)

--//Cache
local localPlayer : Player = nil
local mainGui = nil
local FadeWhiteScreenController = {}

local function FlashWhiteScreen()
    local frame = Instance.new("Frame",mainGui)
    frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    frame.Size = UDim2.new(1,0,1,0)
    frame.ZIndex = 1000
    SoundUtils.PlayLocalSound(SoundService.SFX.FlashWhite)
    SoundUtils.PlayLocalSound(SoundService.SFX.FlashWhite2)
    task.wait(FlashScreenConfig.HoldDuration)

    TweenService:Create(
        frame,
        TweenInfo.new(
            FlashScreenConfig.FlashDuration
        ),
        {
            BackgroundTransparency = 1
        }
    ):Play()

    task.delay(FlashScreenConfig.FlashDuration, function()
        frame:Destroy()
    end)
end

function FadeWhiteScreenController.Start()
    localPlayer = Players.LocalPlayer
    mainGui = localPlayer:WaitForChild("PlayerGui"):WaitForChild("Main")

    Net:Connect(RemoteConfig.UIEffects.FlashWhiteScreen.Name, FlashWhiteScreen)

end

return FadeWhiteScreenController
