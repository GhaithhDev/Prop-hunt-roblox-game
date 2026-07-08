local Services = {}

local allServices = #script:GetDescendants()
local inittedServices = 0
local servicesToInit = {}
for _, descendant in script:GetDescendants() do
	table.insert(servicesToInit,descendant)
end

for _, descendant in game.ReplicatedStorage.Shared.Modules:GetDescendants() do
	table.insert(servicesToInit,descendant)
end
-- Init all Services
for _, service in servicesToInit do
	if not service:IsA("ModuleScript") then continue end

	task.spawn(function()
		local returnval = require(service)
		if typeof(returnval) ~= "table" then
			return
		end

		Services[service.Name] = returnval
		if returnval["Init"] and typeof(returnval["Init"]) == "function" then
			returnval.Init(Services)
		end

		inittedServices += 1
		print("Init'd Service: "..service.Name)
		print(tostring(inittedServices) .. " / "..tostring(allServices).." Services Init'd")
	end)
end

print("All Services Init'd ✅")

local startedServices = 0

for name , service in Services do
	print("trying to start " .. name)
	if service["Start"] and typeof(service["Start"]) == "function" then
		task.spawn(function()
			service.Start(Services)
			startedServices += 1
			print("started " .. name )
			print(tostring(startedServices) .. " / "..tostring(allServices).." Services Started")
		end)

	end
end

print("All Services Init'd and Started ✅")

return Services
