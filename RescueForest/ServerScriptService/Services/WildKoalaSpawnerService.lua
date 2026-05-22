-- WildKoalaSpawnerService Module
-- Handles spawning and wandering of wild Joey koalas in the Rescue Forest.

local WildKoalaSpawnerService = {}

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MAX_WILD_JOEYS = 5
local SPAWN_RADIUS = 200 -- Spawns within -200 to 200 studs from center (0,0)

-- Helper to get ground position via Raycasting on Terrain
local function getGroundPosition()
    local x = math.random(-SPAWN_RADIUS, SPAWN_RADIUS)
    local z = math.random(-SPAWN_RADIUS, SPAWN_RADIUS)
    
    -- Start raycast high up
    local rayOrigin = Vector3.new(x, 150, z)
    local rayDirection = Vector3.new(0, -250, 0)
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    -- Ignore characters and other NPCs
    local ignoreList = {}
    for _, tag in ipairs({"KoalaNPC", "WildJoey"}) do
        for _, instance in ipairs(CollectionService:GetTagged(tag)) do
            table.insert(ignoreList, instance)
        end
    end
    raycastParams.FilterDescendantsInstances = ignoreList
    
    local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
    if result then
        -- Add slight offset so it doesn't clip into terrain
        return result.Position + Vector3.new(0, 1.2, 0)
    end
    return Vector3.new(x, 10, z) -- Fallback
end

-- Helper to find or build the baby koala template
local function getJoeyTemplate()
    local folder = ServerStorage:FindFirstChild("Koalas to pick from") or ServerStorage
    local template = folder:FindFirstChild("Koala Baby")
    if not template then
        local prototypes = ServerStorage:FindFirstChild("Prototypes")
        template = prototypes and prototypes:FindFirstChild("WildJoey")
    end
    if not template then
        template = ServerStorage:FindFirstChild("WildJoey")
    end
    if template then
        return template
    end
    
    -- Self-healing Fallback Model if the actual template isn't imported yet
    local fallback = Instance.new("Model")
    fallback.Name = "WildJoey"
    
    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(1.2, 1.2, 1.2)
    hrp.Color = Color3.fromRGB(150, 150, 150)
    hrp.Material = Enum.Material.Fabric
    hrp.Anchored = false
    hrp.Parent = fallback
    fallback.PrimaryPart = hrp
    
    local hum = Instance.new("Humanoid")
    hum.WalkSpeed = 6
    hum.Parent = fallback
    
    return fallback
end

local function setupJoeyInteraction(joey)
    -- Tag it so it counts towards the limit
    if not CollectionService:HasTag(joey, "WildJoey") then
        CollectionService:AddTag(joey, "WildJoey")
    end
    
    -- Find or create ProximityPrompt
    local promptPart = joey.PrimaryPart or joey:FindFirstChild("HumanoidRootPart") or joey:FindFirstChildOfClass("Part")
    if promptPart then
        local prompt = promptPart:FindFirstChildOfClass("ProximityPrompt")
        if not prompt then
            prompt = Instance.new("ProximityPrompt")
            prompt.Name = "RescuePrompt"
            prompt.Parent = promptPart
        end
        
        -- Configure the prompt to be consistent
        prompt.ActionText = "Feed Milk Bottle 🍼"
        prompt.ObjectText = "Wild Joey"
        prompt.HoldDuration = 0
        prompt.RequiresLineOfSight = false
        prompt.Enabled = true
        
        -- Connect to RescueService.RescueJoey
        prompt.Triggered:Connect(function(player)
            local path = ServerScriptService:FindFirstChild("RescueForest_Services", true) or ServerScriptService:FindFirstChild("Services")
            local RescueService = path and path:FindFirstChild("RescueService") and require(path.RescueService)
            if RescueService then
                RescueService.RescueJoey(player, joey)
            else
                warn("[WildKoalaSpawnerService] RescueService not found!")
            end
        end)
    end
end

function WildKoalaSpawnerService.Initialize()
    -- 1. Hook up all pre-placed joeys in workspace
    for _, child in ipairs(workspace:GetChildren()) do
        if child.Name == "WildJoey" and child:IsA("Model") then
            setupJoeyInteraction(child)
            print("[WildKoalaSpawnerService] Hooked up pre-placed Joey: " .. child:GetFullName())
        end
    end

    -- 2. Hook up any future joeys added to workspace
    workspace.ChildAdded:Connect(function(child)
        if child.Name == "WildJoey" and child:IsA("Model") then
            task.wait() -- Wait a frame for descendants to load
            setupJoeyInteraction(child)
        end
    end)

    -- 3. Start spawn loop
    task.spawn(function()
        while true do
            task.wait(5)
            local currentJoeys = CollectionService:GetTagged("WildJoey")
            if #currentJoeys < MAX_WILD_JOEYS then
                WildKoalaSpawnerService.SpawnJoey()
            end
        end
    end)

    -- 4. Start wandering loop
    task.spawn(function()
        while true do
            task.wait(math.random(4, 8))
            for _, joey in ipairs(CollectionService:GetTagged("WildJoey")) do
                local humanoid = joey:FindFirstChildOfClass("Humanoid")
                local hrp = joey.PrimaryPart or joey:FindFirstChild("HumanoidRootPart")
                if humanoid and hrp and not joey:FindFirstChild("WanderScript") and math.random(1, 100) <= 40 then
                    -- Wander to a nearby random spot
                    local offset = Vector3.new(math.random(-15, 15), 0, math.random(-15, 15))
                    local targetPos = hrp.Position + offset
                    humanoid:MoveTo(targetPos)
                end
            end
        end
    end)
    
    print("[WildKoalaSpawnerService] Initialized and monitoring wild population.")
end

function WildKoalaSpawnerService.SpawnJoey()
    local template = getJoeyTemplate()
    local spawnPos = getGroundPosition()
    
    local joey = template:Clone()
    joey.Name = "WildJoey"
    
    -- Hook up prompt & tag
    setupJoeyInteraction(joey)
    
    joey.Parent = workspace
    joey:PivotTo(CFrame.new(spawnPos))
    
    -- Ensure unanchored so it can walk
    for _, part in ipairs(joey:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = false
            part.CanCollide = true
        end
    end
    
    print("[WildKoalaSpawnerService] Spawned wild Joey at: " .. tostring(spawnPos))
end

return WildKoalaSpawnerService
