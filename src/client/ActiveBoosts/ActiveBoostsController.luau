--[[
	ActiveBoostsController

	Bottom-right HUD widget showing whichever timed boosts are currently
	active, driven entirely by src/shared/Configs/ActiveBoostsConfig.luau -
	a row is cloned in when a boost's remaining-seconds source goes above 0
	and destroyed when it hits 0, for every configured entry regardless of
	scope. Adding a future boost (server-wide event, a second per-player
	boost) is a config-only change, no edits here.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ActiveBoostsConfig = require(ReplicatedStorage.Shared.Configs.ActiveBoostsConfig)

local LocalPlayer = Players.LocalPlayer

local ActiveBoostsController = {}

local activeRows: { [string]: Frame } = {}

local function formatCountdown(remainingSeconds: number): string
	local minutes = math.floor(remainingSeconds / 60)
	local seconds = remainingSeconds % 60
	return string.format("%d:%02d", minutes, seconds)
end

-- Scope = "Server" only for now - MultiplierValueName is read the same way
-- as ValueName per Scope, but no Player-scope boost has needed it yet.
local function readMultiplier(entry: ActiveBoostsConfig.BoostEntry): number?
	if not entry.MultiplierValueName then return nil end
	if entry.Scope == "Server" then
		return Workspace:GetAttribute(entry.MultiplierValueName)
	end
	return nil
end

local function updateRow(container: Frame, template: Frame, entry: ActiveBoostsConfig.BoostEntry, remainingSeconds: number)
	if remainingSeconds > 0 then
		local row = activeRows[entry.Id]
		if not row then
			row = template:Clone()
			row.Name = entry.Id
			row.Visible = true
			row.Parent = container
			activeRows[entry.Id] = row
		end

		local label = row:FindFirstChild("TextLabel")
		if label and label:IsA("TextLabel") then
			local multiplier = readMultiplier(entry)
			if multiplier then
				label.Text = `{entry.DisplayName} x{multiplier}: {formatCountdown(remainingSeconds)}`
			else
				label.Text = `{entry.DisplayName}: {formatCountdown(remainingSeconds)}`
			end
		end
	else
		local row = activeRows[entry.Id]
		if row then
			row:Destroy()
			activeRows[entry.Id] = nil
		end
	end
end

local function wirePlayerScope(container: Frame, template: Frame, entry: ActiveBoostsConfig.BoostEntry)
	local playerData = LocalPlayer:WaitForChild("PlayerData")
	local value = playerData:WaitForChild(entry.ValueName, 5)
	if not value then return end

	updateRow(container, template, entry, value.Value)
	value.Changed:Connect(function()
		updateRow(container, template, entry, value.Value)
	end)
end

local function wireServerScope(container: Frame, template: Frame, entry: ActiveBoostsConfig.BoostEntry)
	local function refresh()
		updateRow(container, template, entry, Workspace:GetAttribute(entry.ValueName) or 0)
	end

	refresh()
	Workspace:GetAttributeChangedSignal(entry.ValueName):Connect(refresh)

	-- A tier upgrade should update the label immediately, not wait for the
	-- next countdown tick.
	if entry.MultiplierValueName then
		Workspace:GetAttributeChangedSignal(entry.MultiplierValueName):Connect(refresh)
	end
end

function ActiveBoostsController.Start()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	local container = playerGui:WaitForChild("Main"):WaitForChild("ActiveBoosts")
	local template = container:WaitForChild("BoostEntryTemplate")

	for _, entry in ActiveBoostsConfig do
		if entry.Scope == "Player" then
			wirePlayerScope(container, template, entry)
		elseif entry.Scope == "Server" then
			wireServerScope(container, template, entry)
		end
	end
end

return ActiveBoostsController
