local ValidationService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

function ValidationService.RunChecks()
	print("[Validation] 🔍 Starting Startup Health Check...")
	local errors = 0
	
	local function check(parent, name, className)
		local found = parent:FindFirstChild(name)
		if not found and parent == ServerStorage and name == "DevWand" then
			-- Check StarterPack too
			found = game:GetService("StarterPack"):FindFirstChild(name)
		end
		
		if not found then
			warn("[Validation] ❌ MISSING: " .. parent.Name .. "." .. name)
			errors += 1
		elseif className and not found:IsA(className) then
			warn("[Validation] ⚠️ WRONG TYPE: " .. parent.Name .. "." .. name .. " (Expected " .. className .. ", got " .. found.ClassName .. ")")
			errors += 1
		end
	end

	-- Check RemoteEvents
	check(ReplicatedStorage, "DevAction", "RemoteEvent")
	check(ReplicatedStorage, "PurchaseToolEvent", "RemoteEvent")
	
	-- Check ServerStorage Assets
	check(ServerStorage, "DevWand", "Tool")
	check(ServerStorage, "WoodenHammer", "Tool")
	check(ServerStorage, "NewKK", "Model")
	
	-- Check Koala templates folder and models
	local koalasFolder = ServerStorage:FindFirstChild("Koalas to pick from")
	if koalasFolder then
		check(koalasFolder, "Koala Baby", "Model")
		check(koalasFolder, "Koala 1 year old", "Model")
		check(koalasFolder, "Koala 2 year old", "Model")
		check(koalasFolder, "Koala", "Model")
	else
		warn("[Validation] ❌ MISSING: ServerStorage.Koalas to pick from")
		errors += 1
	end
	
	-- Check Templates
	local template = ServerStorage:FindFirstChild("Template")
	if template then
		check(template, "TutorialExhibit", "Folder")
	else
		warn("[Validation] ❌ MISSING: ServerStorage.Template")
		errors += 1
	end

	if errors == 0 then
		print("[Validation] ✅ All systems clear! Sync is healthy.")
	else
		warn("[Validation] ⚠️ Found " .. errors .. " sync issues. Check console for details.")
	end
	
	return errors == 0
end

return ValidationService
