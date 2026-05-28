-- ForestDataService Module
-- Handles loading/saving of player data within the Rescue Forest, ensuring tycoon progress is preserved.

local ForestDataService = {}

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local PlayerData = DataStoreService:GetDataStore("KKsKoalaTycoonData_v1")

local sessionData = {} -- player.UserId -> Full player data table

function ForestDataService.Initialize()
    print("[ForestDataService] Initialized.")
end

function ForestDataService.LoadData(player)
    local success, result = pcall(function()
        return PlayerData:GetAsync(tostring(player.UserId))
    end)
    
    if success and result then
        sessionData[player.UserId] = result
        local bottles = result.MilkBottles or 0
        if RunService:IsStudio() and bottles <= 0 then
            bottles = 5
            print(string.format("[ForestDataService] 🛠️ Studio Mode: Granted 5 fallback Milk Bottles to %s for testing.", player.Name))
        end
        player:SetAttribute("MilkBottles", bottles)
        player:SetAttribute("RescuedKoalas", HttpService:JSONEncode(result.RescuedKoalas or {}))
        
        local tycoonKoalas = result.Koalas or {}
        local pendingKoalas = result.RescuedKoalas or {}
        player:SetAttribute("OwnedKoalasCount", #tycoonKoalas + #pendingKoalas)
        
        -- Establish basic leaderstats to show cash/conservation in UI
        local leaderstats = player:FindFirstChild("leaderstats") or Instance.new("Folder", player)
        leaderstats.Name = "leaderstats"
        local cash = leaderstats:FindFirstChild("Cash") or Instance.new("IntValue", leaderstats)
        cash.Name = "Cash"
        cash.Value = result.Cash or 0
        local cons = leaderstats:FindFirstChild("Conservation") or Instance.new("IntValue", leaderstats)
        cons.Name = "Conservation"
        cons.Value = result.Conservation or 0
        
        print(string.format("[ForestDataService] ✅ Loaded data for %s. Cash: %d, Bottles: %d", player.Name, cash.Value, bottles))
    else
        -- Fallback default table so we don't write nil values later
        sessionData[player.UserId] = {
            Cash = 0,
            Conservation = 0,
            HasExhibit = false,
            LeafCount = 0,
            OwnedTools = {},
            Exhibits = {},
            Koalas = {},
            MilkBottles = 0,
            RescuedKoalas = {}
        }
        local bottles = 0
        if RunService:IsStudio() then
            bottles = 5
            print(string.format("[ForestDataService] 🛠️ Studio Mode: Granted 5 fallback Milk Bottles to %s for testing (No Datastore data).", player.Name))
        end
        player:SetAttribute("MilkBottles", bottles)
        player:SetAttribute("RescuedKoalas", "[]")
        player:SetAttribute("OwnedKoalasCount", 0)
        warn("[ForestDataService] ⚠️ No data found or failed to load. Using defaults.")
    end
    player:SetAttribute("DataLoaded", true)
end

function ForestDataService.SaveData(player)
    local data = sessionData[player.UserId]
    if not data then return end
    
    -- Sync updated values from the forest session
    data.MilkBottles = player:GetAttribute("MilkBottles") or 0
    local rescuedAttr = player:GetAttribute("RescuedKoalas") or "[]"
    local decoded = {}
    pcall(function()
        decoded = HttpService:JSONDecode(rescuedAttr)
    end)
    data.RescuedKoalas = decoded
    
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        if leaderstats:FindFirstChild("Cash") then
            data.Cash = leaderstats.Cash.Value
        end
        if leaderstats:FindFirstChild("Conservation") then
            data.Conservation = leaderstats.Conservation.Value
        end
    end
    
    local success, err = pcall(function()
        PlayerData:SetAsync(tostring(player.UserId), data)
    end)
    
    if success then
        print("[ForestDataService] ✅ Saved data successfully for " .. player.Name)
    else
        warn("[ForestDataService] ❌ Failed to save data: " .. tostring(err))
    end
end

function ForestDataService.SyncMilkBottlesToBackpack(player)
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return end
    
    -- Count bottles currently in Backpack + Character
    local currentCount = 0
    for _, item in ipairs(backpack:GetChildren()) do
        if item.Name == "MilkBottle" then
            currentCount = currentCount + 1
        end
    end
    local character = player.Character
    if character then
        for _, item in ipairs(character:GetChildren()) do
            if item.Name == "MilkBottle" then
                currentCount = currentCount + 1
            end
        end
    end
    
    local targetCount = player:GetAttribute("MilkBottles") or 0
    local ServerStorage = game:GetService("ServerStorage")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local bottleTemplate = ServerStorage:FindFirstChild("MilkBottle")
    if not bottleTemplate then
        local forestFolder = ReplicatedStorage:FindFirstChild("Forest")
        bottleTemplate = forestFolder and forestFolder:FindFirstChild("MilkBottle")
    end
    
    if bottleTemplate then
        if currentCount < targetCount then
            local needed = targetCount - currentCount
            print(string.format("[ForestDataService] Cloned %d MilkBottles to %s's Backpack", needed, player.Name))
            for i = 1, needed do
                bottleTemplate:Clone().Parent = backpack
            end
        end
    else
        -- If MilkBottle isn't in ServerStorage, try to build a basic Tool so the game works!
        if currentCount < targetCount then
            warn("[ForestDataService] MilkBottle template not found in ServerStorage! Creating basic tool placeholder.")
            for i = 1, (targetCount - currentCount) do
                local bottle = Instance.new("Tool")
                bottle.Name = "MilkBottle"
                bottle.ToolTip = "Feed a Wild Joey to rescue them!"
                
                local handle = Instance.new("Part", bottle)
                handle.Name = "Handle"
                handle.Size = Vector3.new(0.5, 1, 0.5)
                handle.Color = Color3.fromRGB(240, 240, 240)
                handle.Material = Enum.Material.Plastic
                
                bottle.Parent = backpack
            end
        end
    end
end

return ForestDataService
