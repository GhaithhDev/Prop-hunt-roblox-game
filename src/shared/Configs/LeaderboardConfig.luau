return {
	TopCount = 50, -- entries per board; kept <=100 so one GetSortedAsync page is always enough
	StatSyncInterval = 30, -- seconds between pushing a connected player's current stat, if changed
	DisplayRefreshInterval = 60, -- seconds between re-fetching top N and repopulating the boards
}
