local LeafSpawnerService = {}

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))

local LEAF_TAG = "EucalyptusLeaf"
local MAX_LEAVES_PER_EXHIBIT = 8
local SPAWN_INTERVAL = 6 -- Check every 6 seconds to keep exhibits nicely stocked
local DROP_DURATION = 1.25 -- Seconds for cosmetic leaf drop animation before spawning interactive leaf

local leafTemplate = ServerStorage.Template.TutorialExhibit:FindFirstChild("EucalyptusLeaf")

local function ensureClientLeafTemplate()
	if not leafTemplate then return end
	if ReplicatedStorage:FindFirstChild("LeafDropTemplate") then return end

	local visual = leafTemplate:Clone()
	visual.Name = "LeafDropTemplate"

	for _, desc in ipairs(visual:GetDescendants()) do
		if desc:IsA("ProximityPrompt") or desc:IsA("LuaSourceContainer") then
			desc:Destroy()
		elseif desc:IsA("BasePart") then
			desc.Anchored = true
			desc.CanCollide = false
			desc.CanTouch = false
			desc.CanQuery = false
		end
	end
	if visual:IsA("BasePart") then
		visual.Anchored = true
		visual.CanCollide = false
		visual.CanTouch = false
		visual.CanQuery = false
	end

	visual.Parent = ReplicatedStorage
end

local function countLeavesInExhibit(exhibit)
	local count = 0
	for _, leaf in ipairs(CollectionService:GetTagged(LEAF_TAG)) do
		if leaf:IsDescendantOf(exhibit) then
			count += 1
		end
	end
	return count
end

function LeafSpawnerService.Initialize()
	if not leafTemplate then
		warn("[LeafSpawnerService] Missing leaf template in ServerStorage.Template.TutorialExhibit!")
		return
	end

	ensureClientLeafTemplate()
	Net.Remote("LeafDropVFX")

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
				Net.Signal("ShowStatus"):Fire(player, "⚠️ Your Feed Bag is full! (" .. current .. "/" .. maxLeaves .. ")")
				return
			end

			player:SetAttribute("LeafCount", current + 1)

			-- Visual feedback
			Net.Signal("ShowStatus"):Fire(player, "🌿 Collected Eucalyptus Leaf (" .. (current + 1) .. "/" .. maxLeaves .. ")")

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
		if child.Name == "EucalyptusLeaf" then
			local yPos = nil
			if child:IsA("BasePart") then
				yPos = child.Position.Y
			elseif child:IsA("Model") then
				yPos = child:GetPivot().Position.Y
			end
			if yPos and yPos < 5.8 then
				child:Destroy()
			end
		end
	end

	local leafCount = countLeavesInExhibit(exhibit)

	if leafCount < MAX_LEAVES_PER_EXHIBIT then
		-- Spawn 1 or 2 leaves depending on how depleted the exhibit is
		local toSpawn = (leafCount <= 2) and 2 or 1
		for i = 1, toSpawn do
			if i > 1 then
				task.delay(0.25, function()
					if exhibit.Parent then
						LeafSpawnerService.SpawnLeaf(exhibit)
					end
				end)
			else
				LeafSpawnerService.SpawnLeaf(exhibit)
			end
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

	local targetY = surfaceY + 0.15
	if leaf:IsA("Model") then
		local _, size = leaf:GetBoundingBox()
		targetY = surfaceY + (size.Y * 0.5)
		for _, part in ipairs(leaf:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanCollide = false
			end
		end
		leaf:PivotTo(CFrame.new(rayOrigin.X, targetY, rayOrigin.Z))
	elseif leaf:IsA("BasePart") then
		leaf.Position = Vector3.new(rayOrigin.X, targetY, rayOrigin.Z)
		leaf.Anchored = true
		leaf.CanCollide = false
	end

	local targetPos = Vector3.new(rayOrigin.X, targetY, rayOrigin.Z)
	local treeCF, treeSize = randomTree:GetBoundingBox()
	local canopyMinY = math.max(targetY + 5, treeCF.Position.Y + treeSize.Y * 0.18)
	local canopyMaxY = math.max(canopyMinY + 1, treeCF.Position.Y + treeSize.Y * 0.42)
	local startY = canopyMinY + math.random() * (canopyMaxY - canopyMinY)
	local startPos = Vector3.new(
		targetPos.X + (math.random() - 0.5) * 3,
		startY,
		targetPos.Z + (math.random() - 0.5) * 3
	)

	Net.Remote("LeafDropVFX"):FireAllClients(startPos, targetPos, DROP_DURATION)

	task.delay(DROP_DURATION, function()
		if not exhibit.Parent or countLeavesInExhibit(exhibit) >= MAX_LEAVES_PER_EXHIBIT then
			leaf:Destroy()
			return
		end
		leaf.Parent = exhibit
		CollectionService:AddTag(leaf, LEAF_TAG)
	end)
end

return LeafSpawnerService
