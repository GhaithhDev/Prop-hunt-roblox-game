local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local DataManager = require(ServerScriptService.Server.Data.Manager)
local XpPerPressConfig = require(ReplicatedStorage.Shared.Configs.XpPerPressConfig)

local TOUCH_DEBOUNCE_TIME = .2

local PressXpService = {}

local touchDebounce = {}

-- Call whenever a player's Wins could have changed (awarded or spent) so their
-- equipped option stays in sync with the highest tier they can currently afford.
function PressXpService.RecheckEquippedOption(player: Player)
	local wins = DataManager.Get(player, "Wins") or 0
	local bestOption = XpPerPressConfig.GetBestOptionForWins(wins)
	local currentOption = DataManager.Get(player, "EquippedPressOption")

	if currentOption ~= bestOption then
		DataManager.Set(player, "EquippedPressOption", bestOption)
	end
end

local function OnOptionPartTouched(part, hit)
	local character = hit.Parent
	local player = character and Players:GetPlayerFromCharacter(character)
	if not player then return end

	if touchDebounce[player] then return end
	touchDebounce[player] = true
	task.delay(TOUCH_DEBOUNCE_TIME, function()
		touchDebounce[player] = nil
	end)

	local optionIndex = tonumber(part.Name)
	local option = optionIndex and XpPerPressConfig.Options[optionIndex]
	if not option then return end

	local wins = DataManager.Get(player, "Wins") or 0
	if wins < option.WinsRequired then return end

	local currentOption = DataManager.Get(player, "EquippedPressOption")
	if currentOption == optionIndex then return end

	DataManager.Set(player, "EquippedPressOption", optionIndex)
end

function PressXpService.Start()
	for _, part in workspace.Functional.XpPerPressOptions:GetChildren() do
		part.Touched:Connect(function(hit)
			OnOptionPartTouched(part, hit)
		end)
	end
end

return PressXpService
