local WasteService = {}

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local KoalaConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("KoalaConfig"))
local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))
local KoalaVFX = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("KoalaVFX"))

local WASTE_TAG = "ExhibitWaste"
local KOALA_TAG = "KoalaNPC"
local TICK_INTERVAL = 5

-- Per-koala next waste timestamp (server time)
local nextWasteAt = {}

local function getPoopBotService()
	local ok, mod = pcall(function()
		return require(ServerScriptService:WaitForChild("Services"):WaitForChild("PoopBotService"))
	end)
	return ok and mod or nil
end

local function getWasteFolder(exhibit, createIfMissing)
	local folder = exhibit:FindFirstChild("Waste")
	if not folder and createIfMissing then
		folder = Instance.new("Folder")
		folder.Name = "Waste"
		folder.Parent = exhibit
	end
	return folder
end

local function updateExhibitWasteCount(exhibit)
	if not exhibit then return 0 end
	local count = WasteService.GetWasteCount(exhibit)
	exhibit:SetAttribute("WasteCount", count)
	return count
end

local function findDropPosition(koala, exhibit)
	local hrp = koala:FindFirstChild("HumanoidRootPart") or koala.PrimaryPart
	if not hrp then return nil end

	-- Drop slightly behind the koala
	local behindOffset = -hrp.CFrame.LookVector * 1.5
	local origin = hrp.Position + behindOffset + Vector3.new(0, 2, 0)

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local filterList = { koala }
	local wasteFolder = getWasteFolder(exhibit, false)
	if wasteFolder then
		table.insert(filterList, wasteFolder)
	end
	rayParams.FilterDescendantsInstances = filterList

	local result = workspace:Raycast(origin, Vector3.new(0, -15, 0), rayParams)
	if result then
		return result.Position
	end

	-- Fallback to exhibit Ground top surface
	local ground = exhibit:FindFirstChild("Ground")
	if ground and ground:IsA("BasePart") then
		return Vector3.new(origin.X, ground.Position.Y + (ground.Size.Y * 0.5), origin.Z)
	end

	return Vector3.new(origin.X, hrp.Position.Y - 1, origin.Z)
end

local function createCartoonWasteModel(position)
	local model = Instance.new("Model")
	model.Name = "KoalaWaste"

	local cocoaColor = Color3.fromRGB(115, 78, 52)
	local highlightColor = Color3.fromRGB(130, 90, 62)

	local function makeBlob(name, size, offset, color)
		local part = Instance.new("Part")
		part.Name = name
		part.Shape = Enum.PartType.Ball
		part.Material = Enum.Material.SmoothPlastic
		part.Color = color
		part.Size = size
		part.Position = position + offset
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = true
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
		return part
	end

	-- Cute 3-tier cartoon swirl (not gross!)
	local base = makeBlob("Base", Vector3.new(1.1, 0.55, 1.1), Vector3.new(0, 0.22, 0), cocoaColor)
	makeBlob("Middle", Vector3.new(0.8, 0.45, 0.8), Vector3.new(0, 0.52, 0), cocoaColor)
	local top = makeBlob("Top", Vector3.new(0.45, 0.35, 0.45), Vector3.new(0.05, 0.78, 0), highlightColor)

	model.PrimaryPart = base

	-- Cartoon smell animation: gentle green puff particles
	local smellEmitter = Instance.new("ParticleEmitter")
	smellEmitter.Name = "CartoonSmellParticles"
	smellEmitter.Color = ColorSequence.new(Color3.fromRGB(165, 215, 110))
	smellEmitter.LightEmission = 0.15
	smellEmitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.5, 0.42),
		NumberSequenceKeypoint.new(1, 0),
	})
	smellEmitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.6, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	smellEmitter.Lifetime = NumberRange.new(1.4, 2.2)
	smellEmitter.Rate = 2.5
	smellEmitter.Speed = NumberRange.new(1.0, 1.8)
	smellEmitter.Acceleration = Vector3.new(0, 0.4, 0)
	smellEmitter.SpreadAngle = Vector2.new(25, 25)
	smellEmitter.RotSpeed = NumberRange.new(-45, 45)
	smellEmitter.Rotation = NumberRange.new(0, 360)
	smellEmitter.Parent = top

	-- Subtle cartoon wavy stink line indicator
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CartoonSmellIndicator"
	billboard.Size = UDim2.new(1.6, 0, 1.6, 0)
	billboard.Adornee = top
	billboard.StudsOffset = Vector3.new(0, 0.8, 0)
	billboard.MaxDistance = 45
	billboard.Parent = top

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "💨"
	label.TextScaled = true
	label.TextTransparency = 0.25
	label.Rotation = -90
	label.Parent = billboard

	-- Gentle bobbing animation for the cartoon smell icon
	task.spawn(function()
		local t = math.random() * math.pi * 2
		while model.Parent and billboard.Parent do
			t += 0.12
			billboard.StudsOffset = Vector3.new(math.sin(t) * 0.15, 0.85 + math.abs(math.cos(t * 0.8)) * 0.3, 0)
			label.TextTransparency = 0.25 + (math.sin(t * 1.5) * 0.15 + 0.15)
			task.wait(0.08)
		end
	end)

	return model
end

function WasteService.GetWasteInExhibit(exhibit)
	if not exhibit then return {} end
	local list = {}
	local folder = getWasteFolder(exhibit, false)
	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("Model") and CollectionService:HasTag(child, WASTE_TAG) and not child:GetAttribute("Cleaning") then
				table.insert(list, child)
			end
		end
	end
	return list
end

function WasteService.GetWasteCount(exhibit)
	return #WasteService.GetWasteInExhibit(exhibit)
end

function WasteService.CleanWaste(wasteModel, player)
	if not wasteModel or not wasteModel.Parent then return false end
	if wasteModel:GetAttribute("Cleaning") then return false end

	wasteModel:SetAttribute("Cleaning", true)

	local primary = wasteModel.PrimaryPart or wasteModel:FindFirstChildWhichIsA("BasePart")
	local pos = primary and primary.Position or Vector3.new()
	local prompt = primary and primary:FindFirstChild("CleanWastePrompt")
	if prompt then
		prompt.Enabled = false
	end

	-- Find owning exhibit before destroying
	local folder = wasteModel.Parent
	local exhibit = (folder and folder.Name == "Waste") and folder.Parent or nil

	-- Magic disappear sparkle VFX
	if pos then
		KoalaVFX.ShowCleanSparkleEffect(pos)
	end

	wasteModel:Destroy()

	if exhibit then
		updateExhibitWasteCount(exhibit)
	end

	if player then
		local currentCleanups = player:GetAttribute("ManualCleanups") or 0
		player:SetAttribute("ManualCleanups", currentCleanups + 1)
		Net.Signal("ShowStatus"):Fire(player, "✨ Cleaned up! Koalas are happier!")
	end

	return true
end

function WasteService.SpawnWaste(exhibit, position)
	if not exhibit or not position then return nil end
	if WasteService.GetWasteCount(exhibit) >= KoalaConfig.MAX_WASTE_PER_EXHIBIT then
		return nil
	end

	local folder = getWasteFolder(exhibit, true)
	local wasteModel = createCartoonWasteModel(position)
	wasteModel:SetAttribute("ExhibitName", exhibit.Name)
	wasteModel:SetAttribute("SpawnedAt", workspace:GetServerTimeNow())
	CollectionService:AddTag(wasteModel, WASTE_TAG)

	local primary = wasteModel.PrimaryPart
	if primary then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "CleanWastePrompt"
		prompt.ActionText = "Clean Up"
		prompt.ObjectText = "Koala Waste"
		prompt.HoldDuration = 0.4
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = primary

		prompt.Triggered:Connect(function(player)
			local char = player.Character
			local tool = char and (char:FindFirstChild("Garden Shovel") or char:FindFirstChild("Shovel"))
			if tool then
				WasteService.CleanWaste(wasteModel, player)
			else
				Net.Signal("ShowStatus"):Fire(player, "⚠️ Equip your Garden Shovel to clean up!")
			end
		end)
	end

	wasteModel.Parent = folder
	updateExhibitWasteCount(exhibit)

	local poopBotService = getPoopBotService()
	if poopBotService and exhibit:GetAttribute("HasPoopBot") == true then
		poopBotService.DispatchForExhibit(exhibit)
	end

	return wasteModel
end

function WasteService.TickAllExhibits()
	local now = workspace:GetServerTimeNow()

	-- Prune destroyed koalas from tracking table
	for koala in pairs(nextWasteAt) do
		if not koala or not koala.Parent then
			nextWasteAt[koala] = nil
		end
	end

	for _, exhibit in ipairs(workspace:GetChildren()) do
		if not (exhibit:IsA("Folder") and exhibit.Name:find("_Workspace")) then continue end

		local koalasInExhibit = {}
		for _, child in ipairs(exhibit:GetChildren()) do
			if child:IsA("Model") and CollectionService:HasTag(child, KOALA_TAG) then
				table.insert(koalasInExhibit, child)
			end
		end

		if exhibit:GetAttribute("IsRepaired") ~= true and #koalasInExhibit == 0 then continue end

		local currentWaste = WasteService.GetWasteCount(exhibit)
		if exhibit:GetAttribute("WasteCount") ~= currentWaste then
			exhibit:SetAttribute("WasteCount", currentWaste)
		end

		for _, child in ipairs(koalasInExhibit) do
			-- Skip carried koalas
			if child:GetAttribute("IsCarried") or child:GetAttribute("CarriedBy") then
				continue
			end

			local poopBotService = getPoopBotService()
			local intervalMult = poopBotService and poopBotService.GetWasteIntervalMultiplier(exhibit) or 1.0
			local targetTime = nextWasteAt[child]
			if not targetTime then
				nextWasteAt[child] = now + math.random(KoalaConfig.WASTE_INTERVAL_MIN, KoalaConfig.WASTE_INTERVAL_MAX) * intervalMult
			elseif now >= targetTime then
				nextWasteAt[child] = now + math.random(KoalaConfig.WASTE_INTERVAL_MIN, KoalaConfig.WASTE_INTERVAL_MAX) * intervalMult
				if WasteService.GetWasteCount(exhibit) < KoalaConfig.MAX_WASTE_PER_EXHIBIT then
					local dropPos = findDropPosition(child, exhibit)
					if dropPos then
						WasteService.SpawnWaste(exhibit, dropPos)
					end
				end
			end
		end
	end
end

function WasteService.Initialize()
	if WasteService._initialized then return end
	WasteService._initialized = true

	for _, exhibit in ipairs(workspace:GetChildren()) do
		if exhibit:IsA("Folder") and exhibit.Name:find("_Workspace") then
			updateExhibitWasteCount(exhibit)
		end
	end

	task.spawn(function()
		while true do
			task.wait(TICK_INTERVAL)
			WasteService.TickAllExhibits()
		end
	end)

	print("[WasteService] Initialized (Koala waste & shovel cleanup).")
end

return WasteService
