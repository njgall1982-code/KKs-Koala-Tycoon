-- [[ RESCUE FOREST MAIN SERVER ENTRYPOINT ]]
-- This script manages the initialization of all Rescue Forest systems.
-- It acts similarly to the Tycoon's Main.lua but is tailormade for the adventure forest.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[RescueForest Main] 🚀 Starting systems...")

-- 1. Safe Loading Helper
local function safeRequire(moduleName)
    local path = ServerScriptService:FindFirstChild("RescueForest_Services", true)
    if not path then
        -- Fallback to standard path if flatly structured in Roblox Studio
        path = ServerScriptService:FindFirstChild("Services")
    end
    
    local module = path and path:FindFirstChild(moduleName)
    if not module then
        warn(string.format("[RescueForest Main] ❌ Could not find module: %s", moduleName))
        return nil
    end

    local success, result = pcall(function()
        return require(module)
    end)

    if success then
        print(string.format("[RescueForest Main] loaded service: %s", moduleName))
        return result
    else
        warn(string.format("[RescueForest Main] ❌ Failed to load service: %s | Error: %s", moduleName, tostring(result)))
        return nil
    end
end

-- 2. Load Services
local ForestDataService = safeRequire("ForestDataService")
local TeleportBackToTycoon = safeRequire("TeleportBackToTycoon")
local WildKoalaSpawnerService = safeRequire("WildKoalaSpawnerService")
local RescueService = safeRequire("RescueService")

-- 3. Initialize Services
local function safeInit(service, name)
    if service and service.Initialize then
        local success, err = pcall(function()
            service.Initialize()
        end)
        if success then
            print(string.format("[RescueForest Main] ✅ Initialized: %s", name))
        else
            warn(string.format("[RescueForest Main] ❌ Failed to initialize: %s | Error: %s", name, tostring(err)))
        end
    else
        warn(string.format("[RescueForest Main] ⚠️ Service %s has no Initialize function!", name))
    end
end

safeInit(ForestDataService, "ForestDataService")
safeInit(TeleportBackToTycoon, "TeleportBackToTycoon")
safeInit(WildKoalaSpawnerService, "WildKoalaSpawnerService")
safeInit(RescueService, "RescueService")

print("[RescueForest Main] 🚀 ALL SYSTEMS RUNNING")

-- 4. Player Lifecycle
local function onPlayerAdded(player)
    print("[RescueForest Main] 👤 Player joined: " .. player.Name)
    
    if ForestDataService then
        ForestDataService.LoadData(player)
    end
    
    player.CharacterAdded:Connect(function(character)
        -- Give speed boost for exploration
        local humanoid = character:WaitForChild("Humanoid")
        humanoid.WalkSpeed = 24
        
        -- Sync attributes to Backpack on character spawn/respawn
        task.spawn(function()
            task.wait(1)
            if ForestDataService then
                ForestDataService.SyncMilkBottlesToBackpack(player)
            end
        end)
    end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
    print("[RescueForest Main] 👤 Player leaving: " .. player.Name)
    if ForestDataService then
        ForestDataService.SaveData(player)
    end
end)

game:BindToClose(function()
    print("[RescueForest Main] 🛑 Server shutting down. Saving all players...")
    for _, player in ipairs(Players:GetPlayers()) do
        if ForestDataService then
            ForestDataService.SaveData(player)
        end
    end
    task.wait(2)
end)
