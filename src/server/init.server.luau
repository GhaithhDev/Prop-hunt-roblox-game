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
-- Init all Services - synchronous (no task.spawn) so every service is
-- guaranteed to be registered in `Services` before the Start loop below
-- runs. task.spawn here previously let a yielding require() (e.g. any
-- service pulling in MonetizationService) race past the Start loop's single
-- pass over `Services`, silently dropping that service's Start() entirely.
for _, service in servicesToInit do
	if not service:IsA("ModuleScript") then continue end

	local returnval = require(service)
	if typeof(returnval) ~= "table" then
		continue
	end

	Services[service.Name] = returnval
	if returnval["Init"] and typeof(returnval["Init"]) == "function" then
		returnval.Init(Services)
	end

	inittedServices += 1
	print("Init'd Service: "..service.Name)
	print(tostring(inittedServices) .. " / "..tostring(allServices).." Services Init'd")
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
