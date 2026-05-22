-- RescueService Module
-- Handles the feeding and rescue gacha roll of wild Joey koalas in the forest.

local RescueService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local KoalaConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("KoalaConfig"))

-- Remote Event to notify client of successful rescue details
local rescueNotifyEvent = ReplicatedStorage:FindFirstChild("RescueNotification")
if not rescueNotifyEvent then
    rescueNotifyEvent = Instance.new("RemoteEvent")
    rescueNotifyEvent.Name = "RescueNotification"
    rescueNotifyEvent.Parent = ReplicatedStorage
end

function RescueService.Initialize()
    print("[RescueService] Initialized.")
end

-- Helper to find and consume one Milk Bottle tool from Player's inventory
local function consumeMilkBottleTool(player)
    local backpack = player:FindFirstChild("Backpack")
    local character = player.Character
    
    -- Check character first (equipped tool)
    if character then
        local equipped = character:FindFirstChild("MilkBottle")
        if equipped then
            equipped:Destroy()
            return true
        end
    end
    
    -- Check backpack
    if backpack then
        local bottle = backpack:FindFirstChild("MilkBottle")
        if bottle then
            bottle:Destroy()
            return true
        end
    end
    
    return false
end

function RescueService.RescueJoey(player, joeyInstance)
    local bottlesCount = player:GetAttribute("MilkBottles") or 0
    if bottlesCount <= 0 then
        -- Notify player they have no bottles left
        rescueNotifyEvent:FireClient(player, false, "You don't have any Milk Bottles left! Buy some back at the Tycoon.")
        return
    end

    -- Verify they actually have the MilkBottle tool instance (anti-exploit/sync check)
    local toolConsumed = consumeMilkBottleTool(player)
    if not toolConsumed then
        -- Force-sync if attributes mismatched, but tell them to equip/check
        player:SetAttribute("MilkBottles", 0)
        rescueNotifyEvent:FireClient(player, false, "Could not find a Milk Bottle in your hand or backpack!")
        return
    end

    -- Decrement MilkBottle count attribute
    local newBottleCount = bottlesCount - 1
    player:SetAttribute("MilkBottles", newBottleCount)

    -- Roll Rarity (Cute 90%, Extra Cute 8%, Ultra Cute 2%)
    local rolledRarity = KoalaConfig.RollRarity()
    local rarityName = rolledRarity.name or "Cute"
    local koalaName = KoalaConfig.GetRandomName()

    -- Add to RescuedKoalas pending queue
    local rescuedList = player:GetAttribute("RescuedKoalas") or {}
    table.insert(rescuedList, {
        Name = "Koala",
        DisplayName = koalaName,
        Rarity = rarityName,
        Age = 0
    })
    player:SetAttribute("RescuedKoalas", rescuedList)

    -- Destroy wild Joey in forest
    joeyInstance:Destroy()

    -- Visually place a loaded TransferCrate tool in the player's backpack in the forest
    local transferCrateTemplate = ServerStorage:FindFirstChild("TransferCrate")
    local folder = ServerStorage:FindFirstChild("Koalas to pick from") or ServerStorage
    local koalaTemplate = folder:FindFirstChild("Koala Baby")
    
    if transferCrateTemplate and koalaTemplate then
        task.spawn(function()
            local backpack = player:FindFirstChild("Backpack")
            if backpack then
                local crate = transferCrateTemplate:Clone()
                crate.Parent = backpack
                
                local koala = koalaTemplate:Clone()
                koala.Name = "Koala"
                koala:SetAttribute("DisplayName", koalaName)
                koala:SetAttribute("Rarity", rarityName)
                koala:SetAttribute("Age", 0)
                
                -- Anchor initially to prevent physics glitches
                koala:SetAttribute("AI_Disabled", true)
                for _, p in pairs(koala:GetDescendants()) do
                    if p:IsA("BasePart") then p.Anchored = true end
                end
                
                local CollectionService = game:GetService("CollectionService")
                CollectionService:AddTag(koala, "KoalaNPC")
                koala.Parent = workspace
                
                task.wait(0.1) -- Wait a frame
                
                local handle = crate:FindFirstChild("Handle")
                if handle then
                    local targetRoot = koala:FindFirstChild("HumanoidRootPart") or koala:FindFirstChildOfClass("Part")
                    if targetRoot then
                        local weldTarget = handle:FindFirstChild("KoalaPos") or handle
                        koala:PivotTo(weldTarget.CFrame)
                        
                        for _, p in pairs(koala:GetDescendants()) do
                            if p:IsA("BasePart") then
                                p.CanCollide = false
                                p.Massless = true
                                p.Anchored = false
                            end
                        end
                        
                        local weld = Instance.new("WeldConstraint")
                        weld.Name = "CarryWeld"
                        weld.Part0 = weldTarget
                        weld.Part1 = targetRoot
                        weld.Parent = targetRoot
                        koala.Parent = crate
                        
                        local hum = koala:FindFirstChildOfClass("Humanoid")
                        if hum then hum.PlatformStand = true end
                        
                        koala:SetAttribute("IsBeingCarried", true)
                        player:SetAttribute("Carrying", koala.Name)
                    end
                end
            end
        end)
    end

    -- Trigger immediate save to make it secure
    local path = ServerScriptService:FindFirstChild("RescueForest_Services", true) or ServerScriptService:FindFirstChild("Services")
    local ForestDataService = path and path:FindFirstChild("ForestDataService") and require(path.ForestDataService)
    if ForestDataService then
        ForestDataService.SaveData(player)
    end

    -- Notify client of success with rarity information
    print(string.format("[RescueService] Player %s rescued %s (%s)!", player.Name, koalaName, rarityName))
    rescueNotifyEvent:FireClient(player, true, string.format("You rescued %s! They are a %s Koala! 🐨\nCheck your Tycoon, they have been sent back in a transport crate!", koalaName, rarityName), rarityName)
end

return RescueService
