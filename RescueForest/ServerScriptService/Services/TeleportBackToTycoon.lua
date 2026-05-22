-- TeleportBackToTycoon Module
-- Handles transporting the player back to the main Tycoon place.
-- Saves player data right before teleporting.

local TeleportBackToTycoon = {}

local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TYCOON_PLACE_ID = 101119931747763 

function TeleportBackToTycoon.Initialize()
    local TRUCK_PATH = workspace:WaitForChild("RescueTransport_Truck", 5)
    if not TRUCK_PATH then
        TRUCK_PATH = workspace:WaitForChild("TycoonTransport_Truck", 2) or workspace:FindFirstChild("ReturnPart", true)
    end

    if not TRUCK_PATH then 
        warn("[TeleportBack] No transport part found. Creating a fallback ReturnPart at (0, 5, 0)")
        local fallback = Instance.new("Part")
        fallback.Name = "ReturnPart"
        fallback.Size = Vector3.new(6, 1, 6)
        fallback.Position = Vector3.new(0, 5, 0)
        fallback.Anchored = true
        fallback.Color = Color3.fromRGB(200, 50, 50)
        fallback.Material = Enum.Material.Concrete
        fallback.Parent = workspace
        TRUCK_PATH = fallback
    end

    local prompt = nil
    for _, desc in ipairs(TRUCK_PATH:GetDescendants()) do
        if desc:IsA("ProximityPrompt") then
            prompt = desc
            break
        end
    end

    if not prompt then
        warn("[TeleportBack] ProximityPrompt not found in truck. Creating one.")
        local promptPart = TRUCK_PATH:IsA("BasePart") and TRUCK_PATH or (TRUCK_PATH.PrimaryPart or TRUCK_PATH:FindFirstChild("Part", true))
        if promptPart then
            prompt = Instance.new("ProximityPrompt")
            prompt.Name = "TransportPrompt"
            prompt.ActionText = "Return to Koala Tycoon 🐨"
            prompt.ObjectText = "Rescue Truck"
            prompt.HoldDuration = 2.0
            prompt.RequiresLineOfSight = false
            prompt.Parent = promptPart
        end
    else
        -- Disable any old built-in TeleportScript inside the prompt to prevent conflict
        local oldScript = prompt:FindFirstChild("TeleportScript")
        if oldScript then
            oldScript.Disabled = true
            print("[TeleportBack] Disabled legacy TeleportScript inside proximity prompt.")
        end
    end

    if prompt then
        -- Update properties to match expected standard
        prompt.ActionText = "Return to Koala Tycoon 🐨"
        prompt.ObjectText = "Rescue Truck"
        prompt.HoldDuration = 2.0
        prompt.RequiresLineOfSight = false
        prompt.Enabled = true

        prompt.Triggered:Connect(function(player)
            print("[TeleportBack] Return requested by: " .. player.Name)
            
            -- Trigger visual fade event on client
            local event = ReplicatedStorage:FindFirstChild("TeleportNotification")
            if not event then
                event = Instance.new("RemoteEvent")
                event.Name = "TeleportNotification"
                event.Parent = ReplicatedStorage
            end
            event:FireClient(player)

            -- Save progress immediately before teleporting
            local path = ServerScriptService:FindFirstChild("RescueForest_Services", true) or ServerScriptService:FindFirstChild("Services")
            local ForestDataService = path and path:FindFirstChild("ForestDataService") and require(path.ForestDataService)
            if ForestDataService then
                ForestDataService.SaveData(player)
            else
                warn("[TeleportBack] ForestDataService not found. Cannot force pre-teleport save!")
            end

            if RunService:IsStudio() then
                print("[TeleportBack] ⚠️ Teleportation is disabled in Studio.")
                return
            end

            local success, result = pcall(function()
                local options = Instance.new("TeleportOptions")
                return TeleportService:TeleportAsync(TYCOON_PLACE_ID, {player}, options)
            end)

            if not success then
                warn("[TeleportBack] Teleport failed: " .. tostring(result))
            end
        end)
    end
    
    print("[TeleportBackToTycoon] Initialized.")
end

return TeleportBackToTycoon
