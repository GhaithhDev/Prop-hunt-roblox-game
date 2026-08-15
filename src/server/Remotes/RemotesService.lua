local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net          = require(ReplicatedStorage.Shared.Packages.Net)
local RemoteConfig = require(ReplicatedStorage.Shared.Configs.RemoteConfig)

local RemotesService = {}

local function registerRemotes(node)
    if type(node) ~= "table" then
        return
    end

    if node.Name and node.Type then
        if node.Type == "Event" then
            Net:RemoteEvent(node.Name)
        elseif node.Type == "Function" then
            Net:RemoteFunction(node.Name)
        elseif node.Type == "UnreliableEvent" then
            Net:UnreliableRemoteEvent(node.Name)
        end
        return
    end

    for _, child in node do
        registerRemotes(child)
    end
end

function RemotesService.Init()
    registerRemotes(RemoteConfig)
end

return RemotesService