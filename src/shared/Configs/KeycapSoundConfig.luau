local KeycapSoundConfig = {}

export type SoundEntry = {
	Id: string,
	DisplayName: string,
	Free: boolean,
}

-- Id matches the real Sound instance name under SoundService.SFX.Keyboard
-- exactly; DisplayName matches the card's TextLabel.Text in Main.Sounds
-- exactly (cards aren't uniquely named, only their label text is - lookups
-- match on that). The 8 non-Free entries are all gated behind the single
-- shared MonetizationConfig.GamePasses.KeycapSounds.Unlock pass - buying it
-- unlocks all of them at once, not one pass per sound.
KeycapSoundConfig.Sounds = {
	{ Id = "Alpaca", DisplayName = "ALPACA", Free = true },
	{ Id = "BlackInk", DisplayName = "BLACK INK", Free = true },
	{ Id = "BlueAlps", DisplayName = "BLUE ALPS", Free = true },
	{ Id = "BoxNavy", DisplayName = "BOX NAVY", Free = true },
	{ Id = "CherryBlue", DisplayName = "CHERRY BLUE", Free = false },
	{ Id = "CherryBlack", DisplayName = "CHERRY BLACK", Free = false },
	{ Id = "Panda", DisplayName = "Panda", Free = false },
	{ Id = "Creamy", DisplayName = "Creamy", Free = false },
	{ Id = "Turquoise", DisplayName = "TURQUOISE", Free = false },
	{ Id = "Topre", DisplayName = "TOPRE", Free = false },
	{ Id = "RedInk", DisplayName = "RED INK", Free = false },
	{ Id = "CherryBrown", DisplayName = "CHERRY BROWN", Free = false },
} :: { SoundEntry }

KeycapSoundConfig.DefaultSoundId = "Alpaca"

function KeycapSoundConfig.GetSound(soundId: string): SoundEntry?
	for _, entry in KeycapSoundConfig.Sounds do
		if entry.Id == soundId then
			return entry
		end
	end
	return nil
end

return KeycapSoundConfig
