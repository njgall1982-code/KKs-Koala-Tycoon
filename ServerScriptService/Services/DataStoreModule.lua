-- [VERSION 2.0 - SIMPLIFIED TYCOON]
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local PlayerData = DataStoreService:GetDataStore("KKsKoalaTycoonData_v1")

local DataStore = {}

function DataStore.SaveData(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end
	
	local data = {
		Cash = leaderstats.Cash.Value,
		Conservation = leaderstats.Conservation.Value,
		HasExhibit = player:FindFirstChild("HasExhibit") and player.HasExhibit.Value or false,
		LeafCount = player:GetAttribute("LeafCount") or 0,
		OwnedTools = {}
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
				DisplayName = exhibit:GetAttribute("DisplayName") or ""
			}
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
		print("[DataStore] 💾 Loaded existing data for " .. player.Name)
		cash.Value = result.Cash or 0
		cons.Value = result.Conservation or 0
		he.Value = result.HasExhibit or false
		player:SetAttribute("LeafCount", result.LeafCount or 0)
		
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
	else
		print("[DataStore] ✨ Initializing Default State for " .. player.Name)
		cash.Value = 0
		cons.Value = 0
		he.Value = false
		player:SetAttribute("LeafCount", 0)
	end
	
	player:SetAttribute("DataLoaded", true)
end
return DataStore
