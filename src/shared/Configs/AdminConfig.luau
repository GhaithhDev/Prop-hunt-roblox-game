local AdminConfig = {}

AdminConfig.WHITELIST_ACTIVE = false
AdminConfig.Whitelist = {
	4176117504 -- Put your id here
}

function AdminConfig.IsWhitelisted(player)
	if not AdminConfig.WHITELIST_ACTIVE then
		return true
	end
	return table.find(AdminConfig.Whitelist, player.UserId) ~= nil
end


return AdminConfig