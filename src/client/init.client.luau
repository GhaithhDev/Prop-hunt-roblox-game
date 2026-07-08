local Controllers = {}

local allControllers = #script:GetDescendants()
local inittedControllers = 0

local controllersToInit = {}

for _, descendant in script:GetDescendants() do
	table.insert(controllersToInit,descendant)
end

for _, descendant in game.ReplicatedStorage.Shared.Modules:GetDescendants() do
	table.insert(controllersToInit,descendant)
end

-- Init all Controllers
for _, controller in controllersToInit do
	if not controller:IsA("ModuleScript") then continue end

	local returnval = require(controller)
	if typeof(returnval) ~= "table" then return end

	Controllers[controller.Name] = returnval
	if returnval["Init"] and typeof(returnval["Init"]) == "function" then
		returnval.Init(Controllers)
	end

	inittedControllers += 1
	print("Init'd controller: "..controller.Name)
	print(tostring(inittedControllers) .. " / "..tostring(allControllers).." Controllers Init'd")

end

print("All Controllers Init'd ✅")

local startedControllers = 0

for controllerName , controller in Controllers do
	if controller["Start"] and typeof(controller["Start"]) == "function" then
		task.spawn(function()
			local success , errormsg = pcall(function()
				controller.Start(Controllers)
				startedControllers += 1
				print(tostring(startedControllers) .. " / "..tostring(allControllers).." Controllers Started")
			end)
			if not success then

				if game:GetService("RunService"):IsStudio() then
					error("Error starting controller : " .. controllerName .. " - " .. errormsg)
				else
					warn("Error starting controller : " .. controllerName .. " - " .. errormsg)
				end

			end
		end)
	end
end

print("All Controllers Init'd and Started ✅")

return Controllers
