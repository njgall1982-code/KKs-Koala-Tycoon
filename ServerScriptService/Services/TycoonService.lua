local TycoonService = {}
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local statusEvent = ReplicatedStorage:WaitForChild("UpdateStatus")
local repairEvent = ReplicatedStorage:WaitForChild("RepairExhibitEvent")
local refillEvent = ReplicatedStorage:WaitForChild("RefillFeederEvent")
local FEEDS_FOR_MAX = 5
local FEED_VALUE = 20
function TycoonService.Initialize()
	-- Listen for Repair requests
	repairEvent.OnServerEvent:Connect(function(player, exhibitName)
		local exhibit = workspace:FindFirstChild(exhibitName)
		if not exhibit then return end
		
		-- Check Hammer
		local char = player.Character
		if not char or (not char:FindFirstChild("WoodenHammer") and not player.Backpack:FindFirstChild("WoodenHammer")) then
			TycoonService.UpdateStatus(player, "🔨 You need a hammer to repair this!")
			return
		end
		
		TycoonService.RepairExhibit(player, exhibit)
	end)
	
	-- Listen for Refill requests
	refillEvent.OnServerEvent:Connect(function(player, exhibitName)
		local exhibit = workspace:FindFirstChild(exhibitName)
		if not exhibit then return end
		TycoonService.RefillFeeder(player, exhibit)
	end)
	
	print("[TycoonService] Initialized and listeners active.")
end
function TycoonService.UpdateStatus(player, message)
	statusEvent:FireClient(player, message)
end
function TycoonService.InitializePlayer(player)
	print("[TycoonService] Initializing world for " .. player.Name)
	-- Initial state: All exhibits unrepaired unless attributes say otherwise
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("Folder") and child.Name:find("_Workspace") then
			if not child:GetAttribute("IsRepaired") then
				TycoonService.ApplyVisualState(child, false)
			end
		end
	end
end
function TycoonService.ApplyVisualState(exhibit, isRepaired)
	exhibit:SetAttribute("IsRepaired", isRepaired)
	
	-- Hide/Show based on repair state
	local broken = exhibit:FindFirstChild("BrokenState")
	local repaired = exhibit:FindFirstChild("RepairedState")
	
	if broken then
		for _, p in ipairs(broken:GetDescendants()) do
			if p:IsA("BasePart") then p.Transparency = isRepaired and 1 or 0 p.CanCollide = not isRepaired end
		end
	end
	
	if repaired then
		for _, p in ipairs(repaired:GetDescendants()) do
			if p:IsA("BasePart") then p.Transparency = isRepaired and 0 or 1 p.CanCollide = isRepaired end
		end
	end
	
	-- Manage Prompts
	local ground = exhibit:FindFirstChild("Ground")
	if ground then
		local prompt = ground:FindFirstChild("RepairPrompt")
		if prompt then prompt.Enabled = not isRepaired end
	end
end
function TycoonService.RepairExhibit(player, exhibit)
	if exhibit:GetAttribute("IsRepaired") then return end
	
	local cost = 0 -- Free for now
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats and leaderstats.Cash.Value >= cost then
		leaderstats.Cash.Value -= cost
		TycoonService.ApplyVisualState(exhibit, true)
		TycoonService.UpdateStatus(player, "✅ Exhibit Repaired!")
		
		-- Special tutorial logic
		if exhibit.Name == "TutorialExhibit_Workspace" then
			local QuestService = require(game:GetService("ServerScriptService").Services.QuestService)
			QuestService.UpdateQuest(player, "🌲 Great! Now go to the Forest and find a Koala to rescue!")
		end
	end
end
function TycoonService.RefillFeeder(player, exhibit)
	local leaves = player:GetAttribute("LeafCount") or 0
	if leaves <= 0 then
		TycoonService.UpdateStatus(player, "🌿 You need Eucalyptus Leaves to refill the feeder!")
		return
	end
	
	local currentFood = exhibit:GetAttribute("FoodLevel") or 0
	if currentFood >= 100 then
		TycoonService.UpdateStatus(player, "✅ Feeder is already full!")
		return
	end
	
	-- Use 1 leaf
	player:SetAttribute("LeafCount", leaves - 1)
	local newFood = math.min(100, currentFood + FEED_VALUE)
	exhibit:SetAttribute("FoodLevel", newFood)
	
	TycoonService.UpdateStatus(player, "🥗 Feeder Refilled (" .. newFood .. "%)")
	print("[TycoonService] " .. player.Name .. " refilled " .. exhibit.Name .. " to " .. newFood .. "%")
end
return TycoonService
