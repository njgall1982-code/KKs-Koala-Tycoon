-- [VERSION 2.0 - SIMPLIFIED TYCOON]
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local PlayerData = DataStoreService:GetDataStore("KKsKoalaTycoonData_v1")

local DataStore = {}

function DataStore.SaveData(player)
	print("[DataStore] ⚠️ Persistence DISABLED - Skipping Save for " .. player.Name)
	return
end

function DataStore.LoadData(player)
	print("[DataStore] ⚠️ Persistence DISABLED - Initializing Default State for " .. player.Name)
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
	
	-- DEFAULT VALUES
	cash.Value = 0
	cons.Value = 0
	he.Value = false
	player:SetAttribute("LeafCount", 0)
	
	player:SetAttribute("DataLoaded", true)
end
return DataStore
