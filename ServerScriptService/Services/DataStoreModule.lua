-- [VERSION 2.0 - SIMPLIFIED TYCOON]
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local PlayerData = DataStoreService:GetDataStore("KKsKoalaTycoonData_v1")

local DataStore = {}

function DataStore.SaveData(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	local rescuedAttr = player:GetAttribute("RescuedKoalas") or "[]"
	local rescuedDecoded = {}
	pcall(function()
		rescuedDecoded = HttpService:JSONDecode(rescuedAttr)
	end)

	local unlockedAttr = player:GetAttribute("UnlockedOutfits") or "[]"
	local unlockedDecoded = {}
	pcall(function()
		unlockedDecoded = HttpService:JSONDecode(unlockedAttr)
	end)

	local data = {
		Cash = leaderstats.Cash.Value,
		Conservation = leaderstats.Conservation.Value,
		HasExhibit = player:FindFirstChild("HasExhibit") and player.HasExhibit.Value or false,
		LeafCount = player:GetAttribute("LeafCount") or 0,
		OwnedTools = {},
		MilkBottles = player:GetAttribute("MilkBottles") or 0,
		RescuedKoalas = rescuedDecoded,
		MaxLeaves = player:GetAttribute("MaxLeaves") or 5,
		UnlockedOutfits = unlockedDecoded
	}

	local ownedTools = player:FindFirstChild("OwnedTools")
	if ownedTools then
		for _, tool in ipairs(ownedTools:GetChildren()) do
			table.insert(data.OwnedTools, tool.Name)
		end
	end

	-- Save Exhibit States
	data.Exhibits = {}
	for _, exhibit in ipairs(workspace:GetChildren()) do
		if exhibit:IsA("Folder") and exhibit.Name:find("_Workspace") then
			data.Exhibits[exhibit.Name] = {
				IsRepaired = exhibit:GetAttribute("IsRepaired") or false,
				MaxKoalas = exhibit:GetAttribute("MaxKoalas") or 10,
				MaxFoodLevel = exhibit:GetAttribute("MaxFoodLevel") or 100,
				ExhibitLevel = exhibit:GetAttribute("ExhibitLevel") or 1,
				FeederLevel = exhibit:GetAttribute("FeederLevel") or 1,
				DisplayName = exhibit:GetAttribute("DisplayName") or "",
				WeedsCleared = exhibit:GetAttribute("WeedsCleared") or false
			}
		end
	end

	-- Save Koalas
	data.Koalas = {}
	local CollectionService = game:GetService("CollectionService")
	local koalas = CollectionService:GetTagged("KoalaNPC")
	print("[DataStore] 🐨 Checking " .. #koalas .. " koalas for saving...")

	for _, koala in ipairs(koalas) do
		local stats = koala:FindFirstChild("KoalaStats")
		local home = koala:GetAttribute("HomeExhibit")

		if stats and home and home ~= "" then
			print("[DataStore] ✅ Saving Koala: " .. (koala:GetAttribute("DisplayName") or "Unknown") .. " | Home: " .. tostring(home))
			table.insert(data.Koalas, {
				Name = koala.Name,
				DisplayName = koala:GetAttribute("DisplayName") or koala.Name,
				Rarity = stats:FindFirstChild("Rarity") and stats.Rarity.Value or "Cute",
				Age = stats:FindFirstChild("Age") and stats.Age.Value or 0,
				HomeExhibit = home,
				Outfit = koala:GetAttribute("EquippedOutfit") or ""
			})
		else
			print("[DataStore] ⚠️ Skipping Koala " .. koala.Name .. " (No Stats or HomeExhibit)")
		end
	end

	local success, err = pcall(function()
		PlayerData:SetAsync(tostring(player.UserId), data)
	end)

	if success then
		print("[DataStore] ✅ Saved data for " .. player.Name)
	else
		warn("[DataStore] ❌ Failed to save data for " .. player.Name .. ": " .. tostring(err))
	end
end

function DataStore.LoadData(player)
	local leaderstats = player:FindFirstChild("leaderstats") or Instance.new("Folder", player)
	leaderstats.Name = "leaderstats"
	local cash = leaderstats:FindFirstChild("Cash") or Instance.new("IntValue", leaderstats)
	cash.Name = "Cash"
	local cons = leaderstats:FindFirstChild("Conservation") or Instance.new("IntValue", leaderstats)
	cons.Name = "Conservation"
	local he = player:FindFirstChild("HasExhibit") or Instance.new("BoolValue", player)
	he.Name = "HasExhibit"
	local ot = player:FindFirstChild("OwnedTools") or Instance.new("Folder", player)
	ot.Name = "OwnedTools"

	local success, result = pcall(function()
		return PlayerData:GetAsync(tostring(player.UserId))
	end)

	if success and result then
		print(string.format("[DataStore] 💾 Loaded data for %s: Cash: %d, Cons: %d", player.Name, result.Cash or 0, result.Conservation or 0))
		cash.Value = result.Cash or 0
		cons.Value = result.Conservation or 0
		he.Value = result.HasExhibit or false
		player:SetAttribute("LeafCount", result.LeafCount or 0)
		player:SetAttribute("MilkBottles", result.MilkBottles or 0)
		player:SetAttribute("RescuedKoalas", HttpService:JSONEncode(result.RescuedKoalas or {}))
		player:SetAttribute("MaxLeaves", result.MaxLeaves or 5)
		player:SetAttribute("UnlockedOutfits", HttpService:JSONEncode(result.UnlockedOutfits or {}))
		
		local tycoonKoalas = result.Koalas or {}
		local pendingKoalas = result.RescuedKoalas or {}
		player:SetAttribute("OwnedKoalasCount", #tycoonKoalas + #pendingKoalas)

		-- Give Milk Bottles
		local bottleTemplate = game:GetService("ServerStorage"):FindFirstChild("MilkBottle")
		local bottleCount = result.MilkBottles or 0
		if bottleTemplate and bottleCount > 0 then
			task.spawn(function()
				local backpack = player:WaitForChild("Backpack", 5)
				if backpack then
					for i = 1, bottleCount do
						bottleTemplate:Clone().Parent = backpack
					end
				end
			end)
		end

		-- Spawn Rescued Koalas in Transfer Crates (Tools)
		local rescued = result.RescuedKoalas or {}
		if #rescued > 0 then
			print("[DataStore] 📦 Found " .. #rescued .. " rescued koalas pending delivery!")
			local ServerStorage = game:GetService("ServerStorage")
			local transferCrateTemplate = ServerStorage:FindFirstChild("TransferCrate")
			
			if transferCrateTemplate then
				task.spawn(function()
					task.wait(3) -- Wait for tycoon to initialize and character to load
					local backpack = player:WaitForChild("Backpack", 5)
					if not backpack then return end
					
					local KoalaLifecycle = require(game:GetService("ServerScriptService").Modules.KoalaLifecycle)
					local CarryService = require(game:GetService("ServerScriptService").Services.CarryService)
					local CollectionService = game:GetService("CollectionService")
					local folder = ServerStorage:FindFirstChild("Koalas to pick from") or ServerStorage
					local template = folder:FindFirstChild("Koala Baby")

					for _, kData in ipairs(rescued) do
						local crate = transferCrateTemplate:Clone()
						crate.Parent = backpack
						
						if template then
							local koala = template:Clone()
							koala.Name = kData.Name or "Koala"
							koala:SetAttribute("DisplayName", kData.DisplayName or "Wild Koala")
							
							-- Anchor initially to prevent physics glitches
							koala:SetAttribute("AI_Disabled", true)
							for _, p in pairs(koala:GetDescendants()) do
								if p:IsA("BasePart") then p.Anchored = true end
							end
							
							CollectionService:AddTag(koala, "KoalaNPC")
							koala.Parent = workspace
							
							-- Initialize the stats (rarity, age=0)
							KoalaLifecycle.InitKoala(koala, kData.Rarity or "Cute", kData.Age or 0)
							
							task.wait(0.1) -- Small stabilization delay
							
							-- Weld inside the crate
							local handle = crate:FindFirstChild("Handle")
							if handle then
								local weldTarget = handle:FindFirstChild("KoalaPos") or handle
								CarryService.PickUp(player, koala, weldTarget)
							end
							print("[DataStore] 📦 Loaded and welded " .. koala:GetAttribute("DisplayName") .. " (" .. (kData.Rarity or "Cute") .. ") into player's TransferCrate tool!")
						else
							warn("[DataStore] ❌ Koala Baby template missing. Cannot weld inside TransferCrate.")
						end
					end
				end)
			else
				warn("[DataStore] ❌ TransferCrate template not found in ServerStorage!")
			end
			-- Clear them out on the player instance so they don't save/spawn again
			player:SetAttribute("RescuedKoalas", "[]")
		end

		if result.OwnedTools then
			for _, toolName in ipairs(result.OwnedTools) do
				local tv = Instance.new("StringValue", ot)
				tv.Name = toolName
				tv.Value = toolName
			end
		end

		-- Restore Exhibit States
		if result.Exhibits then
			for exhibitName, stats in pairs(result.Exhibits) do
				local exhibit = workspace:FindFirstChild(exhibitName)
				if exhibit then
					for attrName, attrValue in pairs(stats) do
						if attrValue ~= "" then
							exhibit:SetAttribute(attrName, attrValue)
						end
					end
				end
			end
		end

		-- Restore Koalas
		if result.Koalas and #result.Koalas > 0 then
			print("[DataStore] 🐨 Attempting to restore " .. #result.Koalas .. " koalas...")

			local KoalaLifecycle = require(game:GetService("ServerScriptService").Modules.KoalaLifecycle)
			local KoalaConfig = require(game:GetService("ReplicatedStorage").Modules.KoalaConfig)

			task.spawn(function()
				task.wait(2) -- Extra delay for world stability
				for _, kData in ipairs(result.Koalas) do
					if not kData.HomeExhibit or kData.HomeExhibit == "" then 
						print("[DataStore] ⚠️ Skipping koala " .. kData.DisplayName .. " - No HomeExhibit saved.")
						continue 
					end

					local exhibit = workspace:FindFirstChild(kData.HomeExhibit)
					if exhibit then
						print("[DataStore] 🏗️ Respawning " .. kData.DisplayName .. " in " .. kData.HomeExhibit)
						-- Create a temporary dummy to pass to RespawnAt
						local dummy = Instance.new("Model")
						dummy.Name = kData.Name
						dummy:SetAttribute("DisplayName", kData.DisplayName)
						dummy:SetAttribute("EquippedOutfit", kData.Outfit or "")

						local stats = Instance.new("Folder", dummy)
						stats.Name = "KoalaStats"

						local age = Instance.new("NumberValue", stats)
						age.Name = "Age"
						age.Value = kData.Age

						local rarity = Instance.new("StringValue", stats)
						rarity.Name = "Rarity"
						rarity.Value = kData.Rarity

						-- Help RespawnAt determine the correct stage from Config
						local stageData = KoalaConfig.GetStageForAge(kData.Age)
						local stage = Instance.new("IntValue", stats)
						stage.Name = "Stage"
						stage.Value = stageData.stage

						-- Use RespawnAt with a random scatter to avoid stacking
						local ground = exhibit:FindFirstChild("Ground") or exhibit:FindFirstChildOfClass("BasePart")
						local basePos = ground and ground.Position or Vector3.new(0, 5, 0)
						local scatter = 8 -- Studs of scatter
						-- Calculate ground surface position
						local groundHeight = ground and ground.Size.Y / 2 or 0
						local surfaceY = basePos.Y + groundHeight
						
						local spawnPos = Vector3.new(
							basePos.X + math.random(-scatter, scatter),
							surfaceY + 1, -- 1 stud above ground to match workspace koala
							basePos.Z + math.random(-scatter, scatter)
						)

						KoalaLifecycle.RespawnAt(dummy, spawnPos, exhibit)
					else
						print("[DataStore] ❌ Could not find exhibit: " .. kData.HomeExhibit .. " for koala " .. kData.DisplayName)
					end
				end
			end)
		else
			print("[DataStore] 🐨 No koalas found in save data.")
		end
	else
		print("[DataStore] ✨ Initializing Default State for " .. player.Name)
		cash.Value = 0
		cons.Value = 0
		he.Value = false
		player:SetAttribute("LeafCount", 0)
		player:SetAttribute("MilkBottles", 0)
		player:SetAttribute("RescuedKoalas", "[]")
		player:SetAttribute("MaxLeaves", 5)
		player:SetAttribute("OwnedKoalasCount", 0)
		player:SetAttribute("UnlockedOutfits", "[]")
	end

	player:SetAttribute("DataLoaded", true)
end

-- Safety net for Studio/Server Shutdown
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		DataStore.SaveData(player)
	end
	task.wait(2) -- Give time for async calls
end)

return DataStore
