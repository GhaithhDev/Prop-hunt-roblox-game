local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Net = require(ReplicatedStorage.Shared.Packages.Net)
local KeycapSoundConfig = require(ReplicatedStorage.Shared.Configs.KeycapSoundConfig)
local DataManager = require(ServerScriptService.Server.Data.Manager)
local MonetizationService = require(ServerScriptService.Server.Monetization.MonetizationService)

local KeycapSoundService = {}

local function onEquipKeycapSound(player: Player, soundId: string)
	local entry = KeycapSoundConfig.GetSound(soundId)
	if not entry then
		Net:RemoteEvent("Notify"):FireClient(player, "error", "That sound doesn't exist.")
		return
	end

	if not entry.Free and not MonetizationService.OwnsPass(player, "KeycapSounds", "Unlock") then
		Net:RemoteEvent("Notify"):FireClient(player, "error", "Purchase the Sound Pack to unlock this sound!")
		return
	end

	DataManager.Set(player, "EquippedKeycapSound", soundId)
	Net:RemoteEvent("Notify"):FireClient(player, "success", `Equipped {entry.DisplayName}!`)
end

function KeycapSoundService.Start()
	Net:Handle("EquipKeycapSound", onEquipKeycapSound)
end

return KeycapSoundService
