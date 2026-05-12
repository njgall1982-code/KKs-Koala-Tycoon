-- DevService.lua (Server Script)
-- Handles server-side dev actions triggered by the DevWand UI or RemoteEvents

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local TycoonService = require(game:GetService("ServerScriptService").Services.TycoonService)
local KoalaCoreManager = require(game:GetService("ServerScriptService").Services.KoalaCoreManager)
local CarryService = require(game:GetService("ServerScriptService").Services.CarryService)

local DevService = {}

-- Create the RemoteEvent the client-side LocalScript fires through
local devRemote = ReplicatedStorage:FindFirstChild("DevAction")
if not devRemote then
    devRemote = Instance.new("RemoteEvent")
    devRemote.Name = "DevAction"
    devRemote.Parent = ReplicatedStorage
end

local DEV_IDS = {7094387362, game.CreatorId}

local function giveWand(player)
	-- Check if player is a developer
	local isDev = table.find(DEV_IDS, player.UserId) or (game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId)
	
	if not isDev and not game:GetService("RunService"):IsStudio() then 
		return 
	end

	local function onChar(char)
		local wand = ServerStorage:FindFirstChild("DevWand") or game:GetService("StarterPack"):FindFirstChild("DevWand")
		if wand then
			-- Give to backpack if not there
			if not player.Backpack:FindFirstChild("DevWand") and not char:FindFirstChild("DevWand") then
				wand:Clone().Parent = player.Backpack
			end
		end
	end

	player.CharacterAdded:Connect(onChar)
	if player.Character then onChar(player.Character) end
end

function DevService.Initialize()
	print("[DevService] Initializing DevTool delivery...")
	
    -- Handle new players
    Players.PlayerAdded:Connect(giveWand)
    
    -- Handle existing players (for Studio Play mode)
    for _, player in ipairs(Players:GetPlayers()) do
        task.spawn(giveWand, player)
    end

    -- Handle remote actions
    devRemote.OnServerEvent:Connect(function(player, action, data)
        print("[DevService] Received action: " .. tostring(action))

        if action == "SpawnKoala" then
            local stage = data.stage or 1
            local rarity = data.rarity or "Cute"
            
            local stageData = {
                [1] = {age = 0,    model = "Koala Baby",       scale = 1.0},
                [2] = {age = 1201, model = "Koala 1 year old", scale = 1.0},
                [3] = {age = 2401, model = "Koala 2 year old", scale = 1.0},
                [4] = {age = 3601, model = "Koala",            scale = 1.0},
            }
            local d = stageData[stage] or stageData[1]
            local folder = ServerStorage:FindFirstChild("Koalas to pick from")
            local template = folder and folder:FindFirstChild(d.model)
            
            if template and player.Character then
                -- 1. Ensure Player has a FRESH Crate (to ensure latest scripts)
                local oldCrate = player.Character:FindFirstChild("TransferCrate") or player.Backpack:FindFirstChild("TransferCrate")
                if oldCrate then oldCrate:Destroy() end
                
                local crate = nil
                local crateTemplate = ServerStorage:FindFirstChild("TransferCrate")
                if crateTemplate then
                    crate = crateTemplate:Clone()
                    crate.Parent = player.Backpack
                end

                -- 2. Spawn Koala
                local koala = template:Clone()
                koala.Name = "DevKoala"
                
                -- Anchor all parts to prevent falling before CarryService takes over
                koala:SetAttribute("AI_Disabled", true)
                for _, p in pairs(koala:GetDescendants()) do
                    if p:IsA("BasePart") then p.Anchored = true end
                end

                CollectionService:AddTag(koala, "KoalaNPC")
                koala.Parent = workspace
                koala:PivotTo(player.Character:GetPivot() * CFrame.new(0, 5, -5))
                koala:ScaleTo(d.scale)
                
                KoalaCoreManager.InitKoala(koala, rarity, d.age)

                -- 3. Force Pickup into Crate
                if crate and crate:FindFirstChild("Handle") then
                    local humanoid = player.Character:FindFirstChild("Humanoid")
                    if humanoid then humanoid:EquipTool(crate) end
                    
                    task.wait(0.1) -- Small delay for equip stability
                    
                    -- Use the specific attachment if available for better alignment
                    local weldTarget = crate.Handle:FindFirstChild("KoalaPos") or crate.Handle
                    CarryService.PickUp(player, koala, weldTarget)
                    TycoonService.UpdateStatus(player, "🐨 Loaded Stage " .. stage .. " " .. rarity .. " Koala into Crate!")
                else
                    TycoonService.UpdateStatus(player, "⚠️ Crate missing, spawned loose koala.")
                end
            end

        elseif action == "GrowNearby" then
            local pos = player.Character and player.Character:GetPivot().Position
            if not pos then return end
            local count = 0
            for _, koala in ipairs(CollectionService:GetTagged("KoalaNPC")) do
                if (koala:GetPivot().Position - pos).Magnitude < 40 then
                    local stats = koala:FindFirstChild("KoalaStats")
                    if stats and stats:FindFirstChild("Age") and stats:FindFirstChild("Stage") then
                        if stats.Stage.Value < 4 then
                            local thresholds = {1202, 2402, 3602}
                            stats.Age.Value = thresholds[stats.Stage.Value] or 3602
                            
                            -- Force immediate sync and growth check
                            KoalaCoreManager.RefreshGrowth(koala)
                            
                            count += 1
                        end
                    end
                end
            end
            TycoonService.UpdateStatus(player, "🧪 Growth boost applied to " .. count .. " koalas!")

        elseif action == "AddCash" then
            local amount = tonumber(data) or 5000
            local ls = player:FindFirstChild("leaderstats")
            if ls and ls:FindFirstChild("Cash") then
                ls.Cash.Value += amount
                TycoonService.UpdateStatus(player, "💰 Granted $" .. amount)
            end

        elseif action == "Reset" then
            TycoonService.ClearProgress(player)
            local ls = player:FindFirstChild("leaderstats")
            if ls then
                ls.Cash.Value = 0
                ls.Conservation.Value = 0
            end
            player:SetAttribute("TutorialComplete", nil)
            player.Backpack:ClearAllChildren()
            local wand = ServerStorage:FindFirstChild("DevWand")
            if wand then wand:Clone().Parent = player.Backpack end
            TycoonService.UpdateStatus(player, "🔄 Game Reset!")

        elseif action == "Skip" then
            local ls = player:FindFirstChild("leaderstats")
            if ls then ls.Cash.Value += 10000 end
            player:SetAttribute("TutorialComplete", true)
            TycoonService.UpdateStatus(player, "⚡ Skipped Tutorial!")
        end
    end)
end

return DevService
