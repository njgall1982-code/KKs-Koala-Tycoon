local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

-- Load Validation Service First
local ValidationService = require(ServerScriptService.Services.ValidationService)
ValidationService.RunChecks()

-- Safe Loading Helper
local function safeRequire(modulePath)
	local success, result = pcall(function()
		return require(modulePath)
	end)
	if success then
		return result
	else
		warn("[Main] ❌ Failed to load service: " .. modulePath.Name .. " | Error: " .. tostring(result))
		return nil
	end
end

-- Load Services
-- HOT-SWAP TYCOON/QUEST SYSTEM
local USE_SANDBOX = true

local QuestService, TycoonService
if USE_SANDBOX then
    QuestService = safeRequire(ServerScriptService.Services.QuestService_SANDBOX)
    TycoonService = safeRequire(ServerScriptService.Services.TycoonService_SANDBOX)
else
    QuestService = safeRequire(ServerScriptService.Services.QuestService)
    TycoonService = safeRequire(ServerScriptService.Services.TycoonService)
end

local RevenueService = safeRequire(ServerScriptService.Services.RevenueService)
local LeafSpawnerService = safeRequire(ServerScriptService.Services.LeafSpawnerService)
local HungerService = safeRequire(ServerScriptService.Services.HungerService)

local ShopService = safeRequire(ServerScriptService.Services.ShopService)
local signals = ServerStorage:WaitForChild("Signals")

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

signals.AwardTool.Event:Connect(function(player, toolName, isPermanent)
    if not player then return end
    local toolTemplate = ServerStorage:FindFirstChild(toolName)
    if toolTemplate then
        toolTemplate:Clone().Parent = player.Backpack
        if isPermanent then
            local ownedTools = player:FindFirstChild("OwnedTools")
            if not ownedTools then
                ownedTools = Instance.new("Folder", player)
                ownedTools.Name = "OwnedTools"
            end
            if not ownedTools:FindFirstChild(toolName) then
                local toolValue = Instance.new("StringValue", ownedTools)
                toolValue.Name = toolName
                toolValue.Value = toolName
            end
        end
    end
end)

local ExhibitStatService = safeRequire(ServerScriptService.Services.ExhibitStatService)
local KoalaStatService = safeRequire(ServerScriptService.Services.KoalaStatService)
local KoalaCoreManager = safeRequire(ServerScriptService.Services.KoalaCoreManager)
local CarryService = safeRequire(ServerScriptService.Services.CarryService)
local DevService = safeRequire(ServerScriptService.Services.DevService)
local DataStoreModule = safeRequire(ServerScriptService.Services.DataStoreModule)

-- Tycoon/Quest Event Bus Listeners
if USE_SANDBOX then
    signals:WaitForChild("ForcePickup").Event:Connect(function(player, model)
        if CarryService then
            CarryService.PickUp(player, model)
        end
    end)
end

-- Initialize Systems Safely

local function safeInit(service, name)
	if service and service.Initialize then
		local success, err = pcall(function() service.Initialize() end)
		if not success then
			warn("[Main] ❌ Failed to initialize: " .. name .. " | Error: " .. tostring(err))
		end
	end
end

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

print("[Main] 🚀 STARTING SIMPLIFIED TYCOON LOOP")

local function onPlayerAdded(player)
	print("[Main] 👤 PlayerAdded: " .. player.Name)

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
			local timeout = 10
			local start = tick()
			while not player:GetAttribute("DataLoaded") and (tick() - start) < timeout do
				task.wait(0.2)
			end

			if TycoonService then
				TycoonService.InitializePlayer(player)
			end
			if QuestService then
				if USE_SANDBOX then
					signals:WaitForChild("UpdateQuest"):Fire(player, "👋 Welcome! Repair Exhibit 1 🔨 then talk to the Head Vet 👨‍⚕️")
				else
					QuestService.UpdateQuest(player, "👋 Welcome! Repair Exhibit 1 🔨 then talk to the Head Vet 👨‍⚕️")
				end
			end
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
	task.wait(2)
end)

print("[Main] Tycoon Services Initialized")
