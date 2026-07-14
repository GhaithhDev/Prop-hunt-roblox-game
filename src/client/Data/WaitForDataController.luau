local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local WaitForDataController = {}

-- Required explicitly at the very top of init.client.luau, before any other
-- controller loads. require() blocks the caller until this module's top-level
-- code finishes, so this poll gates the whole client startup on PlayerData
-- (and, below, keycap generation) being ready - no other controller needs its
-- own wait for either. Main.LoadingScreen is Visible = true by default, so
-- it's visible from the instant PlayerGui clones Main in - no race with this
-- script's own timing.
local playerGui = LocalPlayer:WaitForChild("PlayerGui")
local main = playerGui:WaitForChild("Main")
local loadingScreen = main:WaitForChild("LoadingScreen")
local loadingLabel = loadingScreen:WaitForChild("LoadingLabel")
local barContainer = loadingScreen:WaitForChild("BarContainer")
local fill = barContainer:WaitForChild("Fill")
local percentLabel = loadingScreen:WaitForChild("PercentLabel")

local function updateProgress(percent: number)
	fill.Size = UDim2.new(percent / 100, 0, 1, 0)
	percentLabel.Text = percent .. "%"
end

-- Connected before the blocking waits below so it keeps updating while this
-- thread is yielded on them (a signal connection isn't blocked by a :Wait()
-- on a different signal) - read the current value once too, in case
-- generation already made progress before this connected.
updateProgress(Workspace:GetAttribute("KeycapsGenerationProgress") or 0)
Workspace:GetAttributeChangedSignal("KeycapsGenerationProgress"):Connect(function()
	updateProgress(Workspace:GetAttribute("KeycapsGenerationProgress") or 0)
end)

-- Polling instead of WaitForChild avoids the "Infinite yield possible"
-- warning, since the profile load this is waiting on can legitimately take
-- longer than 5 seconds.
loadingScreen.Visible = true
while not LocalPlayer:FindFirstChild("PlayerData") do
	task.wait()
end

if not Workspace:GetAttribute("KeycapsGenerated") then
	Workspace:GetAttributeChangedSignal("KeycapsGenerated"):Wait()
end

local fadeInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
TweenService:Create(loadingScreen, fadeInfo, { BackgroundTransparency = 1 }):Play()
TweenService:Create(barContainer, fadeInfo, { BackgroundTransparency = 1 }):Play()
TweenService:Create(fill, fadeInfo, { BackgroundTransparency = 1 }):Play()
TweenService:Create(loadingLabel, fadeInfo, { TextTransparency = 1 }):Play()
local percentFadeTween = TweenService:Create(percentLabel, fadeInfo, { TextTransparency = 1 })
percentFadeTween:Play()

percentFadeTween.Completed:Once(function()
	loadingScreen.Visible = false
end)

return WaitForDataController
