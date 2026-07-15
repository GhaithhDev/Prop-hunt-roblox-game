local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local AdminConfig = require(ReplicatedStorage.Shared.Configs.AdminConfig)

local TOGGLE_PANEL_KEYBIND = Enum.KeyCode.P

local LocalPlayer = Players.LocalPlayer

local AdminPanelController = {}

local function wireMultiplierSection(section: Frame, action: string)
	local inputBox = section.InputFrame.TextBox
	local durationBox = section.DurationInput.TextBox
	local toggle = section.SpawnFrame.Toggle

	toggle.Activated:Connect(function()
		local multiplier = tonumber(inputBox.Text)
		local duration = tonumber(durationBox.Text)
		if not multiplier or not duration then return end

		Net:RemoteEvent("AdminAction"):FireServer(action, multiplier, duration)
	end)
end

local function wireAnnouncementSection(section: Frame)
	local inputBox = section.InputFrame.TextBox
	local toggle = section.SpawnFrame.Toggle

	toggle.Activated:Connect(function()
		local message = inputBox.Text
		if not message or message == "" then return end

		Net:RemoteEvent("AdminAction"):FireServer("Announce", message)
	end)
end

local function wireSpawnTreadmillsSection(section: Frame)
	local nameBox = section.InputFrame.TextBox
	local durationBox = section.DurationInput.TextBox
	local toggle = section.SpawnFrame.Toggle

	toggle.Activated:Connect(function()
		local name = nameBox.Text
		local duration = tonumber(durationBox.Text)
		if not name or name == "" or not duration then return end

		Net:RemoteEvent("AdminAction"):FireServer("SpawnEventTreadmill", name, duration)
	end)
end

function AdminPanelController.Start(controllers)
	if AdminConfig.WHITELIST_ACTIVE and not table.find(AdminConfig.Whitelist, LocalPlayer.UserId) then
		return
	end

	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local mainGui = playerGui:WaitForChild("Main")
	local panel = mainGui:WaitForChild("AdminPanel")
	local settings = panel:WaitForChild("Settings")

	local PopupController = controllers.PopupController

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode ~= TOGGLE_PANEL_KEYBIND then return end

		if panel.Visible then
			PopupController.Close(panel)
		else
			PopupController.Open(panel)
		end
	end)

	wireMultiplierSection(settings:WaitForChild("SpeedBoost"), "SetXpMultiplier")
	wireMultiplierSection(settings:WaitForChild("WinsBoost"), "SetWinsMultiplier")
	wireAnnouncementSection(settings:WaitForChild("Announcement"))
	wireSpawnTreadmillsSection(settings:WaitForChild("SpawnTreadmills"))
end

return AdminPanelController
