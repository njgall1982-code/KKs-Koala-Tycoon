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
local QuestService = safeRequire(ServerScriptService.Services.QuestService)
local TycoonService = safeRequire(ServerScriptService.Services.TycoonService)
local RevenueService = safeRequire(ServerScriptService.Services.RevenueService)
local LeafSpawnerService = safeRequire(ServerScriptService.Services.LeafSpawnerService)
local HungerService = safeRequire(ServerScriptService.Services.HungerService)
local ShopService = safeRequire(ServerScriptService.Services.ShopService)
local ExhibitStatService = safeRequire(ServerScriptService.Services.ExhibitStatService)
local KoalaStatService = safeRequire(ServerScriptService.Services.KoalaStatService)
local KoalaCoreManager = safeRequire(ServerScriptService.Services.KoalaCoreManager)
local CarryService = safeRequire(ServerScriptService.Services.CarryService)
local DevService = safeRequire(ServerScriptService.Services.DevService)
local DataStoreModule = safeRequire(ServerScriptService.Services.DataStoreModule)
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
				QuestService.UpdateQuest(player, "👋 Welcome! Repair Exhibit 1 🔨 then talk to the Head Vet 👨‍⚕️")
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
