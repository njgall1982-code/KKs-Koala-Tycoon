local main_content = [==[local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

-- 1. Load Validation Service First
local ValidationService = require(ServerScriptService.Services.ValidationService)
ValidationService.RunChecks()

-- 2. Safe Loading Helper
local function safeRequire(modulePath)
	local success, result = pcall(function()
		return require(modulePath)
	end)
	if success then
		return result
	else
		warn("[Main] âŒ Failed to load service: " .. modulePath.Name .. " | Error: " .. tostring(result))
		return nil
	end
end

-- 3. Load ALL Services
local EconomyService = safeRequire(ServerScriptService.Services.EconomyService)
local QuestService = safeRequire(ServerScriptService.Services.QuestService)
local TycoonService = safeRequire(ServerScriptService.Services.TycoonService)
local CarryService = safeRequire(ServerScriptService.Services.CarryService)
local DataStoreModule = safeRequire(ServerScriptService.Services.DataStoreModule)
local RevenueService = safeRequire(ServerScriptService.Services.RevenueService)
local LeafSpawnerService = safeRequire(ServerScriptService.Services.LeafSpawnerService)
local HungerService = safeRequire(ServerScriptService.Services.HungerService)
local ShopService = safeRequire(ServerScriptService.Services.ShopService)
local ExhibitStatService = safeRequire(ServerScriptService.Services.ExhibitStatService)
local KoalaStatService = safeRequire(ServerScriptService.Services.KoalaStatService)
local KoalaCoreManager = safeRequire(ServerScriptService.Services.KoalaCoreManager)
local DevService = safeRequire(ServerScriptService.Services.DevService)

-- 4. Event Bus Listeners
local signals = ServerStorage:WaitForChild("Signals")

-- Force Pickup Listener
signals:WaitForChild("ForcePickup").Event:Connect(function(player, model)
    if CarryService then
        CarryService.PickUp(player, model)
    end
end)

-- Economy Listener
signals.RequestTransaction.OnInvoke = function(player, amount, reason)
    if not player or not player:FindFirstChild("leaderstats") then return false, "No data" end
    local cash = player.leaderstats:FindFirstChild("Cash")
    if cash and cash.Value >= amount then
        cash.Value -= amount
        print("[EconomyBus] Processed " .. reason .. " for " .. player.Name .. ": -$" .. amount)
        return true
    end
    return false, "Insufficient funds"
end

-- Tool Award Listener
signals.AwardTool.Event:Connect(function(player, toolName, isPermanent)
    if not player then return end
    local toolTemplate = ServerStorage:FindFirstChild(toolName)
    if toolTemplate then
        toolTemplate:Clone().Parent = player.Backpack
        if isPermanent then
            local ownedTools = player:FindFirstChild("OwnedTools") or Instance.new("Folder", player)
            ownedTools.Name = "OwnedTools"
            if not ownedTools:FindFirstChild(toolName) then
                local toolValue = Instance.new("StringValue", ownedTools)
                toolValue.Name = toolName
                toolValue.Value = toolName
            end
        end
    end
end)

-- 5. Initialize Systems Safely
local function safeInit(service, name)
	if service and service.Initialize then
		local success, err = pcall(function() service.Initialize() end)
		if not success then
			warn("[Main] âŒ Failed to initialize: " .. name .. " | Error: " .. tostring(err))
		end
	end
end

safeInit(EconomyService, "EconomyService")
safeInit(TycoonService, "TycoonService")
safeInit(QuestService, "QuestService")
safeInit(RevenueService, "RevenueService")
safeInit(LeafSpawnerService, "LeafSpawnerService")
safeInit(HungerService, "HungerService")
safeInit(ShopService, "ShopService")
safeInit(ExhibitStatService, "ExhibitStatService")
safeInit(KoalaStatService, "KoalaStatService")
safeInit(KoalaCoreManager, "KoalaCoreManager")
safeInit(CarryService, "CarryService")
safeInit(DevService, "DevService")

print("[Main] ðŸš€ ALL SYSTEMS INITIALIZED")

-- 6. Player Lifecycle
local function onPlayerAdded(player)
	print("[Main] ðŸ‘¤ PlayerAdded: " .. player.Name)

	-- Load data
	if DataStoreModule then
		DataStoreModule.LoadData(player)
	end

	player.CharacterAdded:Connect(function(character)
		-- Give Starter Hammer
		local hammerTemplate = ServerStorage:FindFirstChild("WoodenHammer")
		if hammerTemplate then
			if not player.Backpack:FindFirstChild("WoodenHammer") and not character:FindFirstChild("WoodenHammer") then
				hammerTemplate:Clone().Parent = player.Backpack
			end
		end

		-- Wait for DataLoaded to apply world state
		task.spawn(function()
			local timeout = 5
			local start = tick()
			while not player:GetAttribute("DataLoaded") and (tick() - start) < timeout do
				task.wait(0.2)
			end

			if TycoonService then
				TycoonService.InitializePlayer(player)
			end
			
			-- Send Welcome Message
			signals.UpdateQuest:Fire(player, "ðŸ‘‹ Welcome! Repair Exhibit 1 ðŸ”¨ then talk to the Head Vet ðŸ‘¨â€âš•ï¸")
		end)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	if DataStoreModule then
		DataStoreModule.SaveData(player)
	end
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		if DataStoreModule then
			DataStoreModule.SaveData(player)
		end
	end
	task.wait(1)
end)

print("[Main] ðŸš€ TYCOON ONLINE")
]==]
local econ_content = [==[-- EconomyService.lua
local EconomyService = {}

local ServerStorage = game:GetService("ServerStorage")
local Signals = ServerStorage:WaitForChild("Signals")
local GrantCurrency = Signals:WaitForChild("GrantCurrency")

function EconomyService.Initialize()
	GrantCurrency.Event:Connect(function(player, amount, currencyType)
		currencyType = currencyType or "Cash"
		
		local leaderstats = player:FindFirstChild("leaderstats")
		if not leaderstats then return end
		
		local currency = leaderstats:FindFirstChild(currencyType)
		if currency and currency:IsA("IntValue") then
			currency.Value += amount
			print(string.format("[EconomyService] %s +%d for %s", currencyType, amount, player.Name))
			
			-- Fire ShowStatus for visual feedback
			local showStatus = Signals:FindFirstChild("ShowStatus")
			if showStatus then
				showStatus:Fire(player, "+" .. amount .. " " .. currencyType, Color3.fromRGB(0, 255, 0))
			end
		end
	end)
	
	print("[EconomyService] Initialized.")
end

return EconomyService
]==]

game:GetService("ServerScriptService").Main.Source = main_content

local services = game:GetService("ServerScriptService"):FindFirstChild("Services")
if services then
    local econScript = services:FindFirstChild("EconomyService")
    if not econScript then
        econScript = Instance.new("ModuleScript", services)
        econScript.Name = "EconomyService"
    end
    econScript.Source = econ_content
end

print("Synced Main and EconomyService to Studio")
