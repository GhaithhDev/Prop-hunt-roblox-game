local Debris       = game:GetService("Debris")
local Players      = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)

local LocalPlayer = Players.LocalPlayer

local ConfettiController = {}

local CONFETTI_COLORS = {
    Color3.fromRGB(255, 0,   0),   Color3.fromRGB(255, 0,   221),
    Color3.fromRGB(157, 0,   255), Color3.fromRGB(0,   187, 255),
    Color3.fromRGB(71,  238, 52),  Color3.fromRGB(255, 176, 0),
    Color3.fromRGB(255, 255, 0),
}

function ConfettiController.Play()
    local playerGui = LocalPlayer:WaitForChild("PlayerGui")

    local sfx   = SoundService:FindFirstChild("SFX")
    local sound = sfx and sfx:FindFirstChild("Confetti")
    if sound then sound:Play() end

    local gui          = Instance.new("ScreenGui")
    gui.Name           = "MatchConfetti"
    gui.ResetOnSpawn   = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder   = 199
    gui.Parent         = playerGui

    local rng = Random.new()
    task.spawn(function()
        for _ = 1, 220 do
            local sw = rng:NextNumber(0.0125, 0.0175)
            local sh = rng:NextNumber(0.05, 0.06)
            local p  = Instance.new("Frame")
            p.Size             = UDim2.new(sw, 0, sh, 0)
            p.BackgroundColor3 = CONFETTI_COLORS[math.random(#CONFETTI_COLORS)]
            p.BorderSizePixel  = 0
            p.AnchorPoint      = Vector2.new(0.5, 0.5)
            p.Position         = UDim2.new(math.random(3, 97) / 100, 0, -0.1, 0)
            p.Rotation         = math.random(-360, 360)
            p.Parent           = gui
            local dur = math.random(11, 17) / 10
            TweenService:Create(p, TweenInfo.new(dur, Enum.EasingStyle.Linear), {
                Rotation = math.random(-360, 360),
                Size     = UDim2.new(sw / 2, 0, sh / 2, 0),
                Position = UDim2.new(p.Position.X.Scale, 0, 1.1, 0),
            }):Play()
            Debris:AddItem(p, dur)
            task.wait(0.0075)
        end
        task.delay(3, function()
            gui:Destroy()
        end)
    end)
end

function ConfettiController.Start()
    Net:Connect("WinAwarded", function()
        ConfettiController.Play()
    end)
end

return ConfettiController
