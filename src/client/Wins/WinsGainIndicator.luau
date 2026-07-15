local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local NumberFormat = require(ReplicatedStorage.Shared.Packages.NumberFormat)

local LocalPlayer = Players.LocalPlayer

local WinsGainIndicator = {}

local BIG_TEXT_IN = TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local BIG_TEXT_OUT = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local BIG_TEXT_HOLD = 0.6

local MIN_TROPHIES, MAX_TROPHIES, SATURATION_AMOUNT = 2, 8, 50
local TROPHY_DURATION_RANGE = { 0.5, 0.8 }
local TROPHY_STAGGER = 0.06

local SHAKE_INFO = TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local SHAKE_ANGLES = { 12, -10, 6, 0 }

local mainGui, winsTemplate, trophyTemplate, winsIcon

local function FadeOutDescendants(instance, tweenInfo)
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("ImageLabel") then
			TweenService:Create(descendant, tweenInfo, { ImageTransparency = 1 }):Play()
		elseif descendant:IsA("TextLabel") then
			TweenService:Create(descendant, tweenInfo, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		elseif descendant:IsA("UIStroke") then
			TweenService:Create(descendant, tweenInfo, { Transparency = 1 }):Play()
		end
	end
end

local function SpawnBigText(amount)
	local clone = winsTemplate:Clone()
	local plusAmountLabel = clone:FindFirstChild("PlusAmount")
	if plusAmountLabel then
		plusAmountLabel.Text = `+{NumberFormat.Format(amount)} Wins`
	end

	local restSize = winsTemplate.Size
	clone.Size = UDim2.new(0, 0, 0, 0)
	clone.Visible = true
	clone.Parent = mainGui

	local growTween = TweenService:Create(clone, BIG_TEXT_IN, { Size = restSize })
	growTween:Play()
	growTween.Completed:Once(function()
		task.wait(BIG_TEXT_HOLD)
		FadeOutDescendants(clone, BIG_TEXT_OUT)
		task.delay(BIG_TEXT_OUT.Time, function()
			clone:Destroy()
		end)
	end)
end

local function GetTrophyCount(amount)
	local t = math.clamp(amount / SATURATION_AMOUNT, 0, 1)
	return math.floor(MIN_TROPHIES + t * (MAX_TROPHIES - MIN_TROPHIES) + 0.5)
end

local function ShakeIcon()
	local sequence = SHAKE_ANGLES
	local function playStep(index)
		if index > #sequence then return end
		local tween = TweenService:Create(winsIcon, SHAKE_INFO, { Rotation = sequence[index] })
		tween:Play()
		tween.Completed:Once(function()
			playStep(index + 1)
		end)
	end
	playStep(1)
end

local function QuadraticBezier(p0, p1, p2, t)
	local a = p0:Lerp(p1, t)
	local b = p1:Lerp(p2, t)
	return a:Lerp(b, t)
end

local function SpawnTrophy(delay)
	task.delay(delay, function()
		if not mainGui.Parent then return end

		local viewportSize = mainGui.AbsoluteSize
		local spawnPoint = Vector2.new(
			math.random(0, math.floor(viewportSize.X)),
			math.random(0, math.floor(viewportSize.Y))
		)
		local targetPoint = winsIcon.AbsolutePosition + winsIcon.AbsoluteSize / 2

		local midpoint = spawnPoint:Lerp(targetPoint, 0.5)
		local direction = (targetPoint - spawnPoint)
		local perpendicular = Vector2.new(-direction.Y, direction.X)
		if perpendicular.Magnitude > 0 then
			perpendicular = perpendicular.Unit
		end
		local arcSide = (math.random(0, 1) == 0) and -1 or 1
		local controlPoint = midpoint + perpendicular * arcSide * math.random(60, 160)

		local clone = trophyTemplate:Clone()
		clone.Position = UDim2.fromOffset(spawnPoint.X, spawnPoint.Y)
		clone.Visible = true
		clone.Parent = mainGui

		local duration = TROPHY_DURATION_RANGE[1] + math.random() * (TROPHY_DURATION_RANGE[2] - TROPHY_DURATION_RANGE[1])
		local driver = Instance.new("NumberValue")
		driver.Value = 0

		driver:GetPropertyChangedSignal("Value"):Connect(function()
			local position = QuadraticBezier(spawnPoint, controlPoint, targetPoint, driver.Value)
			clone.Position = UDim2.fromOffset(position.X, position.Y)
		end)

		local flightTween = TweenService:Create(driver, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = 1 })
		flightTween:Play()
		flightTween.Completed:Once(function()
			driver:Destroy()
			clone:Destroy()
			ShakeIcon()
		end)
	end)
end

local function OnWinsGained(amount)
	SpawnBigText(amount)

	local trophyCount = GetTrophyCount(amount)
	for i = 1, trophyCount do
		SpawnTrophy((i - 1) * TROPHY_STAGGER)
	end
end

function WinsGainIndicator.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	mainGui = playerGui:WaitForChild("Main")
	winsTemplate = mainGui:WaitForChild("+WinsTemplate")
	trophyTemplate = mainGui:WaitForChild("TrophyTemplate")
	winsIcon = mainGui:WaitForChild("WinsCounter"):WaitForChild("ImageLabel")

	local playerData = LocalPlayer:WaitForChild("PlayerData")
	local winsValue = playerData:WaitForChild("Wins")

	local lastWins = winsValue.Value
	winsValue:GetPropertyChangedSignal("Value"):Connect(function()
		local newWins = winsValue.Value
		local delta = newWins - lastWins
		lastWins = newWins
		if delta <= 0 then return end

		OnWinsGained(delta)
	end)
end

return WinsGainIndicator
