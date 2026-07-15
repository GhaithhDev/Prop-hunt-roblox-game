local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)

local LocalPlayer = Players.LocalPlayer

local RebirthController = {}

function RebirthController.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local mainGui = playerGui:WaitForChild("Main")

	local icon = mainGui:WaitForChild("LeftIcons"):WaitForChild("LeftIconsContainer"):WaitForChild("Rebirth"):WaitForChild("Button")
	local frame = mainGui:WaitForChild("Rebirth")

	local oldMultiplierLabel = frame:WaitForChild("OldMultiplayer"):WaitForChild("TextLabel")
	local newMultiplierLabel = frame:WaitForChild("NewMultiplayer"):WaitForChild("TextLabel")
	local oldRebirthLabel = frame:WaitForChild("OldRebirthCounter")
	-- Trailing space is part of the actual instance name in Studio.
	local newRebirthLabel = frame:WaitForChild("NewRebirthCounter ")
	local levelRequirementLabel = frame:WaitForChild("LevelRequirement"):WaitForChild("TextLabel")
	local progressInner = frame:WaitForChild("RebirthProgress"):WaitForChild("Frame")
	local progressLabel = progressInner:WaitForChild("TextLabel")
	local progressFill = progressInner:WaitForChild("Fill")
	local buyRebirthButton = frame:WaitForChild("BuyRebirth")
	local skipRebirthButton = frame:WaitForChild("SkipRebirth")

	local function RefreshStatus()
		local status = Net:Invoke("GetRebirthStatus")

		oldRebirthLabel.Text = `Rebirth {status.Rebirths}`
		newRebirthLabel.Text = `Rebirth {status.Rebirths + 1}`
		oldMultiplierLabel.Text = `x{status.CurrentMultiplier} Speed`
		newMultiplierLabel.Text = `x{status.NextMultiplier} Speed`
		levelRequirementLabel.Text = `Level {status.NextRequiredLevel}`
		progressLabel.Text = `Level {status.Level}/{status.NextRequiredLevel}`

		local fraction = status.NextRequiredLevel > 0
			and math.clamp(status.Level / status.NextRequiredLevel, 0, 1)
			or 1
		TweenService:Create(
			progressFill,
			TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.new(fraction, 0, progressFill.Size.Y.Scale, progressFill.Size.Y.Offset) }
		):Play()
	end

	icon.Activated:Connect(RefreshStatus)

	local playerData = LocalPlayer:WaitForChild("PlayerData")
	local rebirthsValue = playerData:WaitForChild("Rebirths")
	local levelValue = playerData:WaitForChild("Level")

	local function RefreshIfVisible()
		if frame.Visible then
			RefreshStatus()
		end
	end

	rebirthsValue:GetPropertyChangedSignal("Value"):Connect(RefreshIfVisible)
	levelValue:GetPropertyChangedSignal("Value"):Connect(RefreshIfVisible)

	buyRebirthButton.Activated:Connect(function()
		Net:Invoke("PerformRebirth")
		RefreshStatus()
	end)

	skipRebirthButton.Activated:Connect(function()
		Net:RemoteEvent("RequestSkipRebirth"):FireServer()
	end)
end

return RebirthController
