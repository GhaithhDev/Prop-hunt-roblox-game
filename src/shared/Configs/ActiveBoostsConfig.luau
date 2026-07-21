export type BoostScope = "Player" | "Server"

export type BoostEntry = {
	Id: string,
	DisplayName: string,
	Scope: BoostScope,
	-- Player scope: LocalPlayer.PlayerData[ValueName].Value
	-- Server scope: workspace:GetAttribute(ValueName)
	ValueName: string,
	-- Optional: read the same way as ValueName (per Scope) and appended as
	-- "{DisplayName} x{n}: {countdown}" instead of "{DisplayName}: {countdown}".
	MultiplierValueName: string?,
}

-- Each entry drives one row in the bottom-right ActiveBoosts widget (see
-- ActiveBoostsController) whenever its remaining-seconds source is > 0.
-- Adding a future boost (a server-wide event, a second per-player boost) is
-- just a new entry here - no controller changes needed either way.
return {
	{
		Id = "XpBoost",
		DisplayName = "2x XP",
		Scope = "Player",
		ValueName = "XpBoostRemainingSeconds",
	},
	{
		Id = "ServerBoost",
		DisplayName = "Server Boost",
		Scope = "Server",
		ValueName = "ServerBoostRemainingSeconds",
		MultiplierValueName = "ServerBoostMultiplier",
	},
	{
		Id = "AdminXpBoost",
		DisplayName = "Admin Shrink Boost",
		Scope = "Server",
		ValueName = "AdminXpRemainingSeconds",
		MultiplierValueName = "AdminXpMultiplier",
	},
	{
		Id = "AdminWinsBoost",
		DisplayName = "Admin Wins Boost",
		Scope = "Server",
		ValueName = "AdminWinsRemainingSeconds",
		MultiplierValueName = "AdminWinsMultiplier",
	},
} :: { BoostEntry }
