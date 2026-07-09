local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local DataManager = require(ServerScriptService.Server.Data.Manager)
local XpPerPressConfig = require(ReplicatedStorage.Shared.Configs.XpPerPressConfig)

local Tags = require(ReplicatedStorage.Shared.Configs.Tags)
local Net = require(ReplicatedStorage.Shared.Packages.Net)
local NumberFormat = require(ReplicatedStorage.Shared.Packages.NumberFormat)

local TOUCH_DEBOUNCE_TIME = .4

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
	if wins < option.WinsRequired then
		Net:RemoteEvent("Notify"):FireClient(player,"error", "Need " .. NumberFormat.Format(option.WinsRequired) .. " Wins!")
   		return
    end

	local currentOption = DataManager.Get(player, "EquippedPressOption")
	if currentOption == optionIndex then return end

	Net:RemoteEvent("Notify"):FireClient(player,"success", "Equipped +" .. NumberFormat.Format(option.StepAmount) .. " / Step")
	DataManager.Set(player, "EquippedPressOption", optionIndex)
end

function PressXpService.Start()
	for _, part in CollectionService:GetTagged(Tags.BaseXpOptionPart) do
		part.Touched:Connect(function(hit)
			OnOptionPartTouched(part, hit)
		end)
	end
end

return PressXpService
