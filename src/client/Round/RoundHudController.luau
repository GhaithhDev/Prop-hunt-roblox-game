--[[
	RoundHudController

	Round phase/timer HUD + a Seeker-only self-health bar. The widgets
	(StarterGui.Main.RoundPhaseText/SeekerHealthBar) are built directly in
	Studio rather than cloned at runtime - this just wires them up. Winner
	announcements ride the existing Notifications.Notify remote/controller -
	no separate banner needed here.
]]

--//Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

--//Configs
local RemoteConfig = require(ReplicatedStorage.Shared.Configs.RemoteConfig)

--//Packages
local Net = require(ReplicatedStorage.Shared.Packages.Net)
local FrameUtils = require(ReplicatedStorage.Shared.Packages.FrameUtils)
local TimeUtils = require(ReplicatedStorage.Shared.Packages.TimeUtils)

local LocalPlayer = Players.LocalPlayer

local RoundHudController = {}

local mainGui: ScreenGui
local phaseText: TextLabel
local healthBar: Frame
local healthFill: Frame?
local healthLabel: TextLabel?
local hidePhaseOverlay: Frame
local timerText: TextLabel

local currentPhase = "WaitingForPlayers"
local endsAt: number? = nil

-- Tracks Health frame-to-frame so the bar only shakes on damage, not on
-- natural regen/heal - reset whenever the character reference changes so a
-- fresh spawn's nil -> full-health jump doesn't read as damage.
local previousCharacter: Model? = nil
local previousHealth: number? = nil

local PHASE_LABELS = {
	WaitingForPlayers = "Waiting for players...",
	Countdown = "Starting in",
	HidePhase = "Hide!",
	Active = "Hunt!",
}

local function ensureLoaded()
	if phaseText then
		return
	end

	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	mainGui = playerGui:WaitForChild("Main")

	phaseText = mainGui:WaitForChild("RoundPhaseText") :: TextLabel
	healthBar = mainGui:WaitForChild("SeekerHealthBar") :: Frame
	healthFill = healthBar:FindFirstChild("Fill") :: Frame?
	healthLabel = healthBar:FindFirstChild("UnlockedCounter") :: TextLabel?
	hidePhaseOverlay = mainGui:WaitForChild("HidePhaseOverlay") :: Frame
	timerText = hidePhaseOverlay:WaitForChild("TimerText") :: TextLabel
end

local function isLocalPlayerSeeker(): boolean
	local team = LocalPlayer.Team
	return team ~= nil and team.Name == "Seekers"
end

local function formatPhaseText(phase: string, timeLeft: number?): string
	local label = PHASE_LABELS[phase] or phase
	if timeLeft and timeLeft > 0 then
		return `{label} {TimeUtils.Format(math.ceil(timeLeft))}`
	end
	return label
end

local function updatePhaseText()
	local timeLeft = endsAt and math.max(0, endsAt - Workspace:GetServerTimeNow())
	phaseText.Text = formatPhaseText(currentPhase, timeLeft)
end

local function onStatusChanged(phase: string, newEndsAt: number?, extra: { Winner: string? }?)
	currentPhase = phase
	endsAt = newEndsAt

	print(currentPhase)
	if phase == "Ended" and extra and extra.Winner then
		phaseText.Text = `{extra.Winner} win!`
	else
		updatePhaseText()
	end
end

local function updateHealthBar()
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local isSeeker = isLocalPlayerSeeker()

	if character ~= previousCharacter then
		previousCharacter = character
		previousHealth = humanoid and humanoid.Health
	end

	if not isSeeker or not humanoid then
		healthBar.Visible = false
		return
	end

	healthBar.Visible = true

	if previousHealth and humanoid.Health < previousHealth then
		FrameUtils.ShakeFrame(healthBar)
	end
	previousHealth = humanoid.Health

	local ratio = humanoid.MaxHealth > 0 and math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1) or 0
	if healthFill then
		local fillSize = healthFill.Size
		healthFill.Size = UDim2.new(ratio, 0, fillSize.Y.Scale, fillSize.Y.Offset)
	end
	if healthLabel then
		healthLabel.Text = `{math.ceil(humanoid.Health)} / {math.floor(humanoid.MaxHealth)}`
	end
end

local function updateHidePhaseOverlay()
	local showOverlay = isLocalPlayerSeeker() and currentPhase == "HidePhase"
	hidePhaseOverlay.Visible = showOverlay

	if showOverlay then
		local timeLeft = endsAt and math.max(0, endsAt - Workspace:GetServerTimeNow()) or 0
		timerText.Text = "Waiting for Hiders: " .. TimeUtils.Format(math.ceil(timeLeft))
	end
end

local function requestRoundStatus()
	local phase, requestEndsAt, extra = Net:Invoke(RemoteConfig.Round.RequestCurrentStatus.Name)
	if phase then
		onStatusChanged(phase, requestEndsAt, extra)
	end
end

function RoundHudController.Start()
	ensureLoaded()

	Net:Connect(RemoteConfig.Round.StatusChanged.Name, onStatusChanged)
	requestRoundStatus()

	RunService.Heartbeat:Connect(function()
		if currentPhase == "Countdown" or currentPhase == "HidePhase" or currentPhase == "Active" then
			updatePhaseText()
		end
		updateHealthBar()
		updateHidePhaseOverlay()
	end)
	print(currentPhase)
end

return RoundHudController
