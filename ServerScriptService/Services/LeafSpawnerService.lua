local LeafSpawnerService = {}

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local LEAF_TAG = "EucalyptusLeaf"
local MAX_LEAVES_PER_EXHIBIT = 8
local SPAWN_INTERVAL = 15 -- Every 15 seconds try to spawn a leaf

local leafTemplate = ServerStorage.Template.TutorialExhibit:FindFirstChild("EucalyptusLeaf")

function LeafSpawnerService.Initialize()
	if not leafTemplate then
		warn("[LeafSpawnerService] Missing leaf template in ServerStorage.Template.TutorialExhibit!")
		return
	end
	
	-- Handle leaf pickup
	local function onLeafAdded(leaf)
		local prompt = leaf:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt", leaf)
		prompt.ActionText = "Pick Up Leaf 🌿"
		prompt.ObjectText = "Eucalyptus"
		prompt.MaxActivationDistance = 10
		
		prompt.Triggered:Connect(function(player)
			local current = player:GetAttribute("LeafCount") or 0
			local maxLeaves = player:GetAttribute("MaxLeaves") or 5
			
			if current >= maxLeaves then
				local TycoonService = require(game:GetService("ServerScriptService").Services.TycoonService)
				TycoonService.UpdateStatus(player, "⚠️ Your Feed Bag is full! (" .. current .. "/" .. maxLeaves .. ")")
				return
			end
			
			player:SetAttribute("LeafCount", current + 1)
			
			-- Visual feedback
			local TycoonService = require(game:GetService("ServerScriptService").Services.TycoonService)
			TycoonService.UpdateStatus(player, "🌿 Collected Eucalyptus Leaf (" .. (current + 1) .. "/" .. maxLeaves .. ")")
			
			leaf:Destroy()
		end)
	end
	
	CollectionService:GetInstanceAddedSignal(LEAF_TAG):Connect(onLeafAdded)
	for _, leaf in ipairs(CollectionService:GetTagged(LEAF_TAG)) do
		task.spawn(onLeafAdded, leaf)
	end

	-- Spawn loop
	task.spawn(function()
		while true do
			task.wait(SPAWN_INTERVAL)
			LeafSpawnerService.UpdateAllExhibits()
		end
	end)
	
	print("[LeafSpawnerService] Initialized for all exhibits and pickup listener active.")
end

function LeafSpawnerService.UpdateAllExhibits()
	-- Find all exhibit workspaces
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("Folder") and child.Name:find("_Workspace") then
			LeafSpawnerService.CheckAndSpawnForExhibit(child)
		end
	end
end

function LeafSpawnerService.CheckAndSpawnForExhibit(exhibit)
	local currentLeaves = CollectionService:GetTagged(LEAF_TAG)
	local leafCount = 0
	for _, leaf in ipairs(currentLeaves) do
		if leaf:IsDescendantOf(exhibit) then
			leafCount += 1
		end
	end
	
	if leafCount < MAX_LEAVES_PER_EXHIBIT then
		LeafSpawnerService.SpawnLeaf(exhibit)
	end
end

function LeafSpawnerService.SpawnLeaf(exhibit)
	local trees = {}
	-- Search descendants to find trees in subfolders like "Trees"
	for _, descendant in ipairs(exhibit:GetDescendants()) do
		if descendant:IsA("Model") and descendant.Name == "EucalyptusTree" then
			table.insert(trees, descendant)
		end
	end
	
	if #trees == 0 then return end
	
	local randomTree = trees[math.random(1, #trees)]
	local leaf = leafTemplate:Clone()
	
	-- Position the leaf under the tree on the ground
	local treePivot = randomTree:GetPivot()
	local treePos = treePivot.Position
	local groundY = 0
	local ground = exhibit:FindFirstChild("Ground")
	if ground then
		groundY = ground.Position.Y + (ground.Size.Y / 2)
	else
		-- Fallback if ground not found
		groundY = treePos.Y - 5 
	end
	
	local offset = Vector3.new(math.random(-8, 8), 0.2, math.random(-8, 8))
	leaf.Position = Vector3.new(treePos.X + offset.X, groundY + offset.Y, treePos.Z + offset.Z)
	leaf.Parent = exhibit
	
	CollectionService:AddTag(leaf, LEAF_TAG)
end

return LeafSpawnerService
