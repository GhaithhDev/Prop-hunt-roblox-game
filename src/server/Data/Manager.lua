local Manager = {}
Manager.Profiles = {}

function Manager.Get(Player, Key)
	local Profile = Manager.Profiles[Player]
	if not Profile then return nil end
	return Profile.Data[Key]
end

function Manager.GetData(Player)
	local Profile = Manager.Profiles[Player]
	if not Profile then return nil end
	return Profile.Data
end

function Manager.Set(Player, Key, Value)
	local Profile = Manager.Profiles[Player]
	if not Profile then return false end
	Profile.Data[Key] = Value
	Manager.SyncToClient(Player, Key, Value)
	return true
end

function Manager.Add(Player, Key, Amount)
	local Profile = Manager.Profiles[Player]
	if not Profile then return false end
	Profile.Data[Key] = (Profile.Data[Key] or 0) + Amount
	Manager.SyncToClient(Player, Key, Profile.Data[Key])
	return true
end

function Manager.HasInList(Player, Key, Item)
	local Profile = Manager.Profiles[Player]
	if not Profile then return false end
	local List = Profile.Data[Key]
	if not List then return false end
	for _, V in List do
		if V == Item then return true end
	end
	return false
end

function Manager.AddToList(Player, Key, Item)
	local Profile = Manager.Profiles[Player]
	if not Profile then return false end
	if not Profile.Data[Key] then Profile.Data[Key] = {} end
	if Manager.HasInList(Player, Key, Item) then return false end
	table.insert(Profile.Data[Key], Item)
	return true
end

function Manager.Owns(Player, Category, Item)
	local Profile = Manager.Profiles[Player]
	if not Profile then return false end
	local CategoryData = Profile.Data[Category]
	if not CategoryData then return false end
	return CategoryData[Item] == true
end

function Manager.SetOwned(Player, Category, Item, Owned)
	local Profile = Manager.Profiles[Player]
	if not Profile then return false end
	if not Profile.Data[Category] then
		Profile.Data[Category] = {}
	end
	Profile.Data[Category][Item] = Owned
	return true
end

function Manager.SetupLeaderstats(Player)
	if Player:FindFirstChild("leaderstats") then return end
	local Leaderstats = Instance.new("Folder")
	Leaderstats.Name = "leaderstats"
	Leaderstats.Parent = Player

	local Wins = Instance.new("NumberValue")
	Wins.Name = "Wins"
	Wins.Value = 0
	Wins.Parent = Leaderstats

	local Shrink = Instance.new("NumberValue")
	Shrink.Name = "Shrink"
	Shrink.Value = 0
	Shrink.Parent = Leaderstats

	local Rebirths = Instance.new("NumberValue")
	Rebirths.Name = "Rebirths"
	Rebirths.Value = 0
	Rebirths.Parent = Leaderstats
end

function Manager.SyncToClient(Player, Key, Value)
	if not Player or not Player.Parent then return end
	local PlayerData = Player:FindFirstChild("PlayerData")
	local leaderstats = Player:FindFirstChild("leaderstats")
	if not PlayerData then
		PlayerData = Instance.new("Folder")
		PlayerData.Name = "PlayerData"
		PlayerData.Parent = Player
	end
	if type(Value) == "table" then
		return
	end
	local ValueObj = PlayerData:FindFirstChild(Key)
	if not ValueObj then
		if type(Value) == "number" then
			ValueObj = Instance.new("NumberValue")
		elseif type(Value) == "string" then
			ValueObj = Instance.new("StringValue")
		elseif type(Value) == "boolean" then
			ValueObj = Instance.new("BoolValue")
		else
			return
		end
		ValueObj.Name = Key
		ValueObj.Parent = PlayerData
	end
	ValueObj.Value = Value
	if leaderstats and leaderstats:FindFirstChild(Key) then
		leaderstats:FindFirstChild(Key).Value = Value
	end
end

function Manager.SyncAllToClient(Player)
	local Profile = Manager.Profiles[Player]
	if not Profile then return end
	Manager.SetupLeaderstats(Player)
	for Key, Value in Profile.Data do
		Manager.SyncToClient(Player, Key, Value)
	end
end

return Manager
