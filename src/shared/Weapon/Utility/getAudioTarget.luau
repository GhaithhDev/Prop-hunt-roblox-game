local SoundService = game:GetService("SoundService")

--[[
	Optional integration with the newer Audio API's bus/compressor routing, for games
	that have set one up under SoundService.Audio.Busses.<busName>.AudioCompressor.
	Falls back to `fallback` (e.g. the sound's own parent) when no such bus exists,
	so gun audio still plays in projects that haven't set up Audio busses.
]]
local function getAudioTarget(busName: string, fallback: Instance): Instance
	local audio = SoundService:FindFirstChild("Audio")
	local busses = audio and audio:FindFirstChild("Busses")
	local bus = busses and busses:FindFirstChild(busName)
	local compressor = bus and bus:FindFirstChild("AudioCompressor")
	return compressor or fallback
end

return getAudioTarget
