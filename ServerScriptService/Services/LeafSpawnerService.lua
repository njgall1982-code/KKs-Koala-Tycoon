local LeafSpawnerService = {}

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local LEAF_TAG = "EucalyptusLeaf"
local MAX_LEAVES_PER_EXHIBIT = 8
local SPAWN_INTERVAL = 6 -- Check every 6 seconds to keep exhibits nicely stocked

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
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false

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

	-- Initial spawn check on start
	task.defer(function()
		LeafSpawnerService.UpdateAllExhibits()
	end)

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
	-- Remove any broken/underground leaves from legacy spawns
	for _, child in ipairs(exhibit:GetChildren()) do
		if child.Name == "EucalyptusLeaf" and child:IsA("BasePart") and child.Position.Y < 5.8 then
			child:Destroy()
		end
	end

	local currentLeaves = CollectionService:GetTagged(LEAF_TAG)
	local leafCount = 0
	for _, leaf in ipairs(currentLeaves) do
		if leaf:IsDescendantOf(exhibit) then
			leafCount += 1
		end
	end

	if leafCount < MAX_LEAVES_PER_EXHIBIT then
		-- Spawn 1 or 2 leaves depending on how depleted the exhibit is
		local toSpawn = (leafCount <= 2) and 2 or 1
		for _ = 1, toSpawn do
			LeafSpawnerService.SpawnLeaf(exhibit)
		end
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

	-- Position the leaf under the tree on the ground using raycasting for perfect surface alignment
	local treePivot = randomTree:GetPivot()
	local treePos = treePivot.Position
	local offset = Vector3.new(math.random(-5, 5), 0, math.random(-5, 5))
	local rayOrigin = Vector3.new(treePos.X + offset.X, treePos.Y + 15, treePos.Z + offset.Z)

	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = {randomTree, exhibit:FindFirstChild("Trees")}
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local rayResult = workspace:Raycast(rayOrigin, Vector3.new(0, -50, 0), rayParams)
	local surfaceY = rayResult and rayResult.Position.Y or 6.0

	leaf.Position = Vector3.new(rayOrigin.X, surfaceY + 0.15, rayOrigin.Z)
	leaf.Anchored = true
	leaf.CanCollide = false
	leaf.Parent = exhibit

	CollectionService:AddTag(leaf, LEAF_TAG)
end

return LeafSpawnerService
