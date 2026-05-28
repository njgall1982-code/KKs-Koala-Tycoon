-- WildKoalaSpawnerService Module
-- Handles spawning and wandering of wild Joey koalas in the Rescue Forest.

local WildKoalaSpawnerService = {}

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local MAX_WILD_JOEYS = 5
local joeyStates = {}

-- Helper to locate all designated spawn area parts in Workspace
local function getSpawnAreas()
    local areas = {}
    
    -- 1. Check for folder of spawn areas
    local folder = workspace:FindFirstChild("KoalaSpawnAreas")
    if folder then
        for _, child in ipairs(folder:GetChildren()) do
            if child:IsA("BasePart") then
                table.insert(areas, child)
            end
        end
    end
    
    -- 2. Check for parts tagged with "KoalaSpawnArea"
    for _, tagged in ipairs(CollectionService:GetTagged("KoalaSpawnArea")) do
        if tagged:IsA("BasePart") and not table.find(areas, tagged) then
            table.insert(areas, tagged)
        end
    end
    
    -- 3. Check for a single part named "KoalaSpawnArea"
    local single = workspace:FindFirstChild("KoalaSpawnArea")
    if single and single:IsA("BasePart") and not table.find(areas, single) then
        table.insert(areas, single)
    end
    
    -- 4. Constructor Fallback Pattern: Create default spawn area if none exist
    if #areas == 0 then
        local defaultArea = Instance.new("Part")
        defaultArea.Name = "KoalaSpawnArea"
        defaultArea.Size = Vector3.new(200, 10, 200)
        defaultArea.Position = Vector3.new(0, 18, -20)
        defaultArea.Anchored = true
        defaultArea.CanCollide = false
        defaultArea.Transparency = 1
        defaultArea.Color = Color3.fromRGB(0, 255, 0)
        defaultArea.Material = Enum.Material.ForceField
        defaultArea.Parent = workspace
        
        CollectionService:AddTag(defaultArea, "KoalaSpawnArea")
        table.insert(areas, defaultArea)
        print("[WildKoalaSpawnerService] Created default KoalaSpawnArea Part in Workspace.")
    end
    
    return areas
end

-- Helper to get ground position via Raycasting on Terrain inside designated spawn areas
local function getGroundPosition()
    local areas = getSpawnAreas()
    local spawnArea = areas[math.random(1, #areas)]
    
    local size = spawnArea.Size
    local cframe = spawnArea.CFrame
    
    -- Pick a random offset within the spawn area bounding box
    local rx = math.random(-size.X/2, size.X/2)
    local rz = math.random(-size.Z/2, size.Z/2)
    
    local relativePos = Vector3.new(rx, 0, rz)
    local worldPos = cframe:PointToWorldSpace(relativePos)
    
    -- Start raycast high up relative to the chosen point
    local rayOrigin = Vector3.new(worldPos.X, worldPos.Y + 100, worldPos.Z)
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
    return Vector3.new(worldPos.X, worldPos.Y, worldPos.Z) -- Fallback
end

-- Helper to find or build the baby koala template
local function getJoeyTemplate()
    -- 1. Try Koala Baby from ServerStorage
    local template = ServerStorage:FindFirstChild("Koala Baby")
    
    -- 2. Try Koala Baby from Prototypes
    if not template then
        local prototypes = ServerStorage:FindFirstChild("Prototypes")
        template = prototypes and prototypes:FindFirstChild("Koala Baby")
    end
    
    -- 3. Try Koalas to pick from folder
    if not template then
        local folder = ServerStorage:FindFirstChild("Koalas to pick from")
        template = folder and folder:FindFirstChild("Koala Baby")
    end
    
    -- 4. Fallback search for old WildJoey template
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
    fallback.Name = "Koala Baby"
    
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
    
    local humanoid = joey:FindFirstChildOfClass("Humanoid")
    local hrp = joey.PrimaryPart or joey:FindFirstChild("HumanoidRootPart")
    
    -- Setup regular Weld for waddling
    if hrp and humanoid then
        local rigRoot = joey:FindFirstChild("Koala_Quads") or joey:FindFirstChild("char1") or joey:FindFirstChild("Mesh_0")
        if not rigRoot then
            for _, child in ipairs(joey:GetChildren()) do
                if child:IsA("MeshPart") and child ~= hrp then
                    rigRoot = child
                    break
                end
            end
        end
        
        if rigRoot then
            local rootWeld = nil
            for _, descendant in ipairs(joey:GetDescendants()) do
                if descendant:IsA("WeldConstraint") or descendant:IsA("Weld") or descendant:IsA("Motor6D") then
                    if (descendant.Part0 == hrp and descendant.Part1 == rigRoot) or (descendant.Part0 == rigRoot and descendant.Part1 == hrp) then
                        if descendant:IsA("WeldConstraint") then
                            descendant:Destroy()
                        else
                            rootWeld = descendant
                        end
                    end
                end
            end
            
            if not rootWeld then
                rootWeld = Instance.new("Weld")
                rootWeld.Name = "RigRootWeld"
                rootWeld.Part0 = hrp
                rootWeld.Part1 = rigRoot
                rootWeld.C0 = hrp.CFrame:ToObjectSpace(rigRoot.CFrame)
                rootWeld.C1 = CFrame.new()
                rootWeld.Parent = hrp
            else
                rootWeld.Part0 = hrp
                rootWeld.Part1 = rigRoot
                rootWeld.C0 = hrp.CFrame:ToObjectSpace(rigRoot.CFrame)
                rootWeld.C1 = CFrame.new()
            end
            
            joeyStates[joey] = {
                joey = joey,
                humanoid = humanoid,
                hrp = hrp,
                rootWeld = rootWeld,
                baseC0 = rootWeld.C0,
                animTime = 0,
                currentSpeed = 0
            }
        end
    end
    
    -- Find or create ProximityPrompt
    local promptPart = hrp or joey:FindFirstChildOfClass("Part")
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
    
    -- 5. Heartbeat loop for procedural waddle animation
    RunService.Heartbeat:Connect(function(dt)
        for joey, state in pairs(joeyStates) do
            if not joey.Parent then
                joeyStates[joey] = nil
                continue
            end
            
            local hrp = state.hrp
            local humanoid = state.humanoid
            local rootWeld = state.rootWeld
            
            if hrp and humanoid and rootWeld and rootWeld.Parent then
                local velocity = hrp.AssemblyLinearVelocity
                local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
                if speed < 0.1 then
                    -- Fallback to humanoid movement direction
                    speed = humanoid.MoveDirection.Magnitude * 3
                end
                
                local isMoving = speed > 0.5
                local targetSpeed = isMoving and 1 or 0
                state.currentSpeed = state.currentSpeed + (targetSpeed - state.currentSpeed) * 0.2
                state.animTime = state.animTime + dt * 3 * state.currentSpeed
                
                local cycle = state.animTime * 6 / 3 -- WADDLE_SPEED = 6, WALK_SPEED = 3
                local bounce = math.abs(math.sin(cycle * 2)) * 0.08 * state.currentSpeed
                local sway = math.sin(cycle) * 0.06 * state.currentSpeed
                local roll = math.sin(cycle) * math.rad(6) * state.currentSpeed
                local yaw = math.cos(cycle) * math.rad(4) * state.currentSpeed
                local pitch = (math.sin(cycle * 2) * math.rad(2) + math.rad(2)) * state.currentSpeed
                
                rootWeld.C0 = state.baseC0 
                    * CFrame.new(sway, bounce, 0) 
                    * CFrame.Angles(pitch, yaw, roll)
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
