local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

-- Pre-create TeleportNotification RemoteEvent to prevent client scripts from yielding
local teleportNotification = ReplicatedStorage:FindFirstChild("TeleportNotification")
if not teleportNotification then
	teleportNotification = Instance.new("RemoteEvent")
	teleportNotification.Name = "TeleportNotification"
	teleportNotification.Parent = ReplicatedStorage
end

-- 1. Load Validation Service First
local ValidationService = require(ServerScriptService.Services.ValidationService)
ValidationService.RunChecks()

-- 2. Safe Loading Helper
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

-- 3. Load ALL Services
local EconomyService = safeRequire(ServerScriptService.Services.EconomyService)
local QuestService = safeRequire(ServerScriptService.Services.QuestService)
local TycoonService = safeRequire(ServerScriptService.Services.TycoonService)
local CarryService = safeRequire(ServerScriptService.Services.CarryService)
local DataStoreModule = safeRequire(ServerScriptService.Services.DataStoreModule)
local RevenueService = safeRequire(ServerScriptService.Services.RevenueService)
local LeafSpawnerService = safeRequire(ServerScriptService.Services.LeafSpawnerService)
local HungerService = safeRequire(ServerScriptService.Services.HungerService)
local ShopService = safeRequire(ServerScriptService.Services.ShopService)
local ExhibitStatService = safeRequire(ServerScriptService.Services.ExhibitStatService)
local KoalaStatService = safeRequire(ServerScriptService.Services.KoalaStatService)
local KoalaCoreManager = safeRequire(ServerScriptService.Services.KoalaCoreManager)
local ExhibitUpgradeService = safeRequire(ServerScriptService.Services.ExhibitUpgradeService)
local DevService = safeRequire(ServerScriptService.Services.DevService)
local FeederVisualService = safeRequire(ServerScriptService.Services.FeederVisualService)
local KoalaOutfitService = safeRequire(ServerScriptService.Services.KoalaOutfitService)

-- New Refactored Services
local KoalaSystem = safeRequire(ServerScriptService.Services.KoalaSystem)
local TeleportToForest = safeRequire(ServerScriptService.Services.TeleportToForest)

-- 4. Event Bus Listeners
local signals = ServerStorage:WaitForChild("Signals")

-- Force Pickup Listener
signals:WaitForChild("ForcePickup").Event:Connect(function(player, model)
	if CarryService then
		CarryService.PickUp(player, model)
	end
end)

-- Tool Award Listener
signals.AwardTool.Event:Connect(function(player, toolName, isPermanent)
	if not player then return end
	local toolTemplate = ServerStorage:FindFirstChild(toolName)
	if toolTemplate then
		toolTemplate:Clone().Parent = player.Backpack
		if isPermanent then
			-- Add to StarterGear so it persists through death
			local starterGear = player:FindFirstChild("StarterGear")
			if starterGear and not starterGear:FindFirstChild(toolName) then
				toolTemplate:Clone().Parent = starterGear
			end

			local ownedTools = player:FindFirstChild("OwnedTools") or Instance.new("Folder", player)
			ownedTools.Name = "OwnedTools"
			if not ownedTools:FindFirstChild(toolName) then
				local toolValue = Instance.new("StringValue", ownedTools)
				toolValue.Name = toolName
				toolValue.Value = toolName
			end
		end
	end
end)

-- Create FeedBag tool in ServerStorage dynamically if it is missing
local feedBagTemplate = ServerStorage:FindFirstChild("FeedBag")
if not feedBagTemplate then
	feedBagTemplate = Instance.new("Tool")
	feedBagTemplate.Name = "FeedBag"
	feedBagTemplate.ToolTip = "Holds Eucalyptus Leaves to refill feeders"
	feedBagTemplate.RequiresHandle = false
	feedBagTemplate.Parent = ServerStorage
	print("[Main] 🌿 Created FeedBag template dynamically in ServerStorage.")
end

-- 5. Initialize Systems Safely
local function safeInit(service, name)
	if service and service.Initialize then
		local success, err = pcall(function() service.Initialize() end)
		if not success then
			warn("[Main] ❌ Failed to initialize: " .. name .. " | Error: " .. tostring(err))
		end
	end
end

safeInit(EconomyService, "EconomyService")

safeInit(TycoonService, "TycoonService")
safeInit(QuestService, "QuestService")
safeInit(RevenueService, "RevenueService")
safeInit(LeafSpawnerService, "LeafSpawnerService")
safeInit(HungerService, "HungerService")
safeInit(ShopService, "ShopService")
safeInit(ExhibitStatService, "ExhibitStatService")
safeInit(KoalaStatService, "KoalaStatService")
safeInit(KoalaCoreManager, "KoalaCoreManager")
safeInit(ExhibitUpgradeService, "ExhibitUpgradeService")
safeInit(CarryService, "CarryService")
safeInit(DevService, "DevService")
safeInit(FeederVisualService, "FeederVisualService")
safeInit(KoalaOutfitService, "KoalaOutfitService")

-- New Services
safeInit(KoalaSystem, "KoalaSystem")
safeInit(TeleportToForest, "TeleportToForest")

print("[Main] 🚀 ALL SYSTEMS INITIALIZED")

-- 6. Player Lifecycle
local function onPlayerAdded(player)
	print("[Main] 👤 PlayerAdded: " .. player.Name)

	-- Load data
	if DataStoreModule then
		DataStoreModule.LoadData(player)
	end

	local function setupCharacter(character)
		-- Give Starter Hammer
		local hammerTemplate = ServerStorage:FindFirstChild("WoodenHammer")
		if hammerTemplate then
			if not player.Backpack:FindFirstChild("WoodenHammer") and not character:FindFirstChild("WoodenHammer") then
				hammerTemplate:Clone().Parent = player.Backpack
			end
		end

		-- Give Feed Bag
		local feedBagTemplate = ServerStorage:FindFirstChild("FeedBag")
		if feedBagTemplate then
			if not player.Backpack:FindFirstChild("FeedBag") and not character:FindFirstChild("FeedBag") then
				feedBagTemplate:Clone().Parent = player.Backpack
			end
		end

		-- Apply Run Speed
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.WalkSpeed = 24

		-- Wait for DataLoaded to apply world state and tools
		task.spawn(function()
			local timeout = 5
			local start = tick()
			while not player:GetAttribute("DataLoaded") and (tick() - start) < timeout do
				task.wait(0.2)
			end

			-- Sync Owned Tools to Backpack/StarterGear
			local ownedTools = player:FindFirstChild("OwnedTools")
			if ownedTools then
				for _, tVal in ipairs(ownedTools:GetChildren()) do
					local toolName = tVal.Name
					-- Legacy Mapping
					if toolName == "Shovel" then toolName = "Garden Shovel" end

					local toolTemplate = ServerStorage:FindFirstChild(toolName)
					if toolTemplate then
						if not player.Backpack:FindFirstChild(tVal.Name) and not character:FindFirstChild(tVal.Name) then
							toolTemplate:Clone().Parent = player.Backpack
						end
						local starterGear = player:FindFirstChild("StarterGear")
						if starterGear and not starterGear:FindFirstChild(tVal.Name) then
							toolTemplate:Clone().Parent = starterGear
						end
					end
				end
			end

			if TycoonService then
				TycoonService.InitializePlayer(player)
			end

			-- Send Welcome Message (only if tutorial not completed)
			local hasExhibit = player:FindFirstChild("HasExhibit")
			if hasExhibit and not hasExhibit.Value then
				signals.UpdateQuest:Fire(player, "👋 Welcome! Repair Exhibit 1 🔨 then talk to the Head Vet 👨‍⚕️")
			else
				signals.UpdateQuest:Fire(player, "")
			end
		end)
	end

	player.CharacterAdded:Connect(setupCharacter)
	if player.Character then
		task.spawn(setupCharacter, player.Character)
	end
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
	task.wait(1)
end)

print("[Main] 🚀 TYCOON ONLINE")
