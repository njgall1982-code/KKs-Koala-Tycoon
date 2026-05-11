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

	local conservation = leaderstats:FindFirstChild("Conservation") or Instance.new("IntValue", leaderstats)
	conservation.Name = "Conservation"

	local hasExhibit = player:FindFirstChild("HasExhibit") or Instance.new("BoolValue", player)
	hasExhibit.Name = "HasExhibit"

	local ownedTools = player:FindFirstChild("OwnedTools") or Instance.new("Folder", player)
	ownedTools.Name = "OwnedTools"

	-- DEFAULT VALUES
	cash.Value = 0
	conservation.Value = 0
	hasExhibit.Value = false
	player:SetAttribute("TutorialComplete", false)
	player:SetAttribute("LeafCount", 0)

	player:SetAttribute("DataLoaded", true)
end

return DataStore
