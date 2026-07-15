local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BridgeConfig = require(ReplicatedStorage.Shared.Configs.BridgeConfig)

local UPDATE_INTERVAL = 0.05

local BridgeController = {}

local function formatTime(remaining: number): string
	remaining = math.max(remaining, 0)
	local whole = math.floor(remaining)
	local hundredths = math.floor((remaining - whole) * 100)
	return string.format("%d:%02d", whole, hundredths)
end

function BridgeController.Start()
	local bridge = workspace.Functional:FindFirstChild("Bridge")
	if not bridge then
		warn("BridgeController: Workspace.Functional.Bridge not found - skipping")
		return
	end

	local timer = bridge:FindFirstChild("Timer")
	local textLabel = timer and timer:FindFirstChild("SurfaceGui") and timer.SurfaceGui:FindFirstChild("Frame") and timer.SurfaceGui.Frame:FindFirstChild("TextLabel")
	if not textLabel then
		warn("BridgeController: Bridge.Timer.SurfaceGui.Frame.TextLabel not found - skipping")
		return
	end

	task.spawn(function()
		while true do
			local phaseStart = bridge:GetAttribute("PhaseStartTime")
			if phaseStart then
				local elapsed = Workspace:GetServerTimeNow() - phaseStart
				if elapsed < BridgeConfig.CountdownDuration then
					textLabel.Text = formatTime(BridgeConfig.CountdownDuration - elapsed)
				else
					textLabel.Text = "Wait..."
				end
			end

			task.wait(UPDATE_INTERVAL)
		end
	end)
end

return BridgeController
