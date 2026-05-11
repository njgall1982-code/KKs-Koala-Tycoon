local DevService = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local actionEvent = ReplicatedStorage:WaitForChild("DevAction")
local KoalaCoreManager = require(game:GetService("ServerScriptService").Services.KoalaCoreManager)
function DevService.Initialize()
	actionEvent.OnServerEvent:Connect(function(player, action, data)
		-- Safety check: In a real game, check for Admin/Dev permissions here
		-- if not IsAdmin(player) then return end
		
		print("[DevService] Received action: " .. tostring(action) .. " from " .. player.Name)
		
		if action == "SpawnKoala" then
			DevService.SpawnKoala(player, data)
		elseif action == "ClearAll" then
			DevService.ClearAll()
		elseif action == "GiveCash" then
			DevService.GiveCash(player, 1000)
		elseif action == "ResetData" then
			DevService.ResetData(player)
		elseif action == "GrowKoala" then
			DevService.GrowKoala(player, data)
		end
	end)
end
function DevService.SpawnKoala(player, rarityName)
	local char = player.Character
	if not char then return end
	
	local spawnPos = char:GetPivot().Position + (char:GetPivot().LookVector * 10)
	
	-- Default template for Dev Spawn
	local template = ServerStorage:FindFirstChild("Koalas to pick from")
	if template then
		template = template:FindFirstChild("Koala")
	end
	
	if template then
		local koala = template:Clone()
		koala.Name = "Koala"
		CollectionService:AddTag(koala, "KoalaNPC")
		
		-- Find nearest exhibit to home them (Optional)
		local nearestExhibit = nil
		local minDist = 100
		for _, child in pairs(workspace:GetChildren()) do
			if child.Name:match("_Workspace$") then
				local dist = (child:GetPivot().Position - spawnPos).Magnitude
				if dist < minDist then
					minDist = dist
					nearestExhibit = child
				end
			end
		end
		
		if nearestExhibit then
			koala:SetAttribute("HomeExhibit", nearestExhibit.Name)
			koala.Parent = nearestExhibit
		else
			koala.Parent = workspace
		end
		
		koala:PivotTo(CFrame.new(spawnPos + Vector3.new(0, 2, 0)))
		
		-- Use provided rarity or roll if nil
		local rarity = rarityName
		if not rarity then
			local roll = KoalaCoreManager.RollRarity()
			rarity = roll.name
		end
		
		-- IMPORTANT: Init lifecycle
		KoalaCoreManager.InitKoala(koala, rarity, 3600) -- Default to adult age for dev spawns
		
		print("[DevService] Spawned " .. rarity .. " Koala for " .. player.Name)
	else
		warn("[DevService] Missing Koala template in ServerStorage!")
	end
end
function DevService.GrowKoala(player, koala)
	if not koala then return end
	local stats = koala:FindFirstChild("KoalaStats")
	if not stats then return end
	
	local currentAge = stats.Age.Value
	local currentStage = stats.Stage.Value
	
	if currentStage < 4 then
		-- Advance to next stage threshold
		local nextThreshold = 0
		if currentStage == 1 then nextThreshold = 1200
		elseif currentStage == 2 then nextThreshold = 2400
		elseif currentStage == 3 then nextThreshold = 3600
		end
		
		stats.Age.Value = nextThreshold
		KoalaCoreManager.RefreshGrowth(koala)
		print("[DevService] Forced growth on " .. koala.Name)
	else
		print("[DevService] Koala is already an adult.")
	end
end
function DevService.ClearAll()
	local tagged = CollectionService:GetTagged("KoalaNPC")
	for _, k in pairs(tagged) do
		k:Destroy()
	end
	print("[DevService] Cleared all Koala NPCs.")
end
function DevService.GiveCash(player, amount)
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats and leaderstats:FindFirstChild("Cash") then
		leaderstats.Cash.Value += amount
		print("[DevService] Gave $" .. amount .. " to " .. player.Name)
	end
end
function DevService.ResetData(player)
	-- Since persistence is disabled, we just reload defaults
	local DataStore = require(game:GetService("ServerScriptService").Services.DataStoreModule)
	DataStore.LoadData(player)
	
	-- Also reset world state for them
	local TycoonService = require(game:GetService("ServerScriptService").Services.TycoonService)
	TycoonService.InitializePlayer(player)
	
	print("[DevService] Reset session data for " .. player.Name)
end
return DevService
