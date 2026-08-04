local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Packages.Net)

local LocalPlayer = Players.LocalPlayer

local AutoWinsController = {}

function AutoWinsController.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local autoWinsFrame = playerGui:WaitForChild("Main"):WaitForChild("RightIcons"):WaitForChild("AutoWins")
	local button = autoWinsFrame:WaitForChild("Button")
	local enabledColor = autoWinsFrame:WaitForChild("EnabledColor")
	local disabledColor = autoWinsFrame:WaitForChild("DisabledColor")

	local PlayerScripts = LocalPlayer:WaitForChild("PlayerScripts")
	local PlayerModule = require(PlayerScripts:WaitForChild("PlayerModule"))
	local controlModule = PlayerModule:GetControls()

	local autoWinsEnabled = false

	local function updateState(enabled: boolean)
		autoWinsEnabled = enabled
		autoWinsFrame.BackgroundColor3 = enabled and enabledColor.Value or disabledColor.Value
	end

	button.Activated:Connect(function()
		updateState(not autoWinsEnabled)
		Net:RemoteEvent("SetAutoWins"):FireServer(autoWinsEnabled)
	end)

	-- Auto wins moves the character server-side; if the player provides their
	-- own movement input, that's them taking control back, so force it off.
	RunService.RenderStepped:Connect(function()
		if not autoWinsEnabled then
			return
		end

		local moveVector = controlModule:GetMoveVector()
		if moveVector.Magnitude > 0 then
			updateState(false)
			Net:RemoteEvent("SetAutoWins"):FireServer(false)
		end
	end)

	updateState(false)
end

return AutoWinsController