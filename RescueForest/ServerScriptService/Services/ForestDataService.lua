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

function ForestDataService.SyncRescuedKoalasToBackpack(player)
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return end

    local rescuedAttr = player:GetAttribute("RescuedKoalas") or "[]"
    local rescuedList = {}
    pcall(function()
        rescuedList = HttpService:JSONDecode(rescuedAttr)
    end)
    if #rescuedList == 0 then return end

    -- Count existing crates in backpack and character
    local currentCrates = 0
    local searchContainers = {backpack, player.Character}
    for _, c in ipairs(searchContainers) do
        if c then
            for _, item in ipairs(c:GetChildren()) do
                if item:IsA("Tool") and (item.Name == "TransferCrate" or item.Name == "CratedKoala") then
                    currentCrates = currentCrates + 1
                end
            end
        end
    end

    if currentCrates >= #rescuedList then return end

    local ServerStorage = game:GetService("ServerStorage")
    local transferCrateTemplate = ServerStorage:FindFirstChild("CratedKoala")
        or (ServerStorage:FindFirstChild("Prototypes") and ServerStorage.Prototypes:FindFirstChild("CratedKoala"))
        or ServerStorage:FindFirstChild("TransferCrate")
        
    local koalaTemplate = ServerStorage:FindFirstChild("Koala Baby")
        or (ServerStorage:FindFirstChild("Prototypes") and ServerStorage.Prototypes:FindFirstChild("Koala Baby"))
        or ServerStorage:FindFirstChild("WildJoey")
        or (ServerStorage:FindFirstChild("Prototypes") and ServerStorage.Prototypes:FindFirstChild("WildJoey"))
        or (ServerStorage:FindFirstChild("Koalas to pick from") and ServerStorage["Koalas to pick from"]:FindFirstChild("Koala Baby"))

    if not transferCrateTemplate then return end

    for i = currentCrates + 1, #rescuedList do
        local kData = rescuedList[i]
        local crate = transferCrateTemplate:Clone()
        crate:SetAttribute("RescuedKoalaData", HttpService:JSONEncode(kData))
        crate.ToolTip = string.format("Contains: %s (%s)", kData.DisplayName or "Wild Koala", kData.Rarity or "Cute")
        crate.Parent = backpack

        if koalaTemplate then
            local koala = koalaTemplate:Clone()
            koala.Name = "Koala"
            koala:SetAttribute("DisplayName", kData.DisplayName or "Wild Koala")
            koala:SetAttribute("Rarity", kData.Rarity or "Cute")
            koala:SetAttribute("Age", kData.Age or 0)
            koala:SetAttribute("HasBeenNamed", true)

            for _, p in pairs(koala:GetDescendants()) do
                if p:IsA("BasePart") then p.Anchored = true end
            end
            koala.Parent = workspace
            task.wait(0.05)

            local handle = crate:FindFirstChild("Handle")
            if handle then
                local targetRoot = koala:FindFirstChild("HumanoidRootPart") or koala:FindFirstChildOfClass("Part")
                local weldTarget = handle:FindFirstChild("KoalaPos") or handle
                if targetRoot and weldTarget then
                    if weldTarget:IsA("Attachment") then
                        koala:PivotTo(weldTarget.WorldCFrame)
                    else
                        koala:PivotTo(weldTarget.CFrame)
                    end
                    for _, p in pairs(koala:GetDescendants()) do
                        if p:IsA("BasePart") then
                            p.CanCollide = false
                            p.Massless = true
                            p.Anchored = false
                        end
                    end
                    local weld = Instance.new("WeldConstraint")
                    weld.Name = "CarryWeld"
                    local part0 = weldTarget:IsA("Attachment") and weldTarget.Parent or weldTarget
                    weld.Part0 = part0
                    weld.Part1 = targetRoot
                    weld.Parent = targetRoot
                    koala.Parent = crate
                    local hum = koala:FindFirstChildOfClass("Humanoid")
                    if hum then hum.PlatformStand = true end
                    koala:SetAttribute("IsBeingCarried", true)
                end
            end
        end
    end
end

return ForestDataService
