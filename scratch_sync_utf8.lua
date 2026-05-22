local km_content = [==[local KoalaCoreManager = {}

local CollectionService = game:GetService("CollectionService")
local ServerStorage    = game:GetService("ServerStorage")
local RunService       = game:GetService("RunService")

-- ============================================================
-- CONFIG
-- ============================================================

-- Growth time thresholds in SECONDS of "active" growth time.
-- Growth only ticks when Protected (Adult nearby) or CuddleBoost is active.
local GROWTH_STAGES = {
	-- { Stage, Name, ModelName, Scale, MinAge (seconds active), MaxAge }
	{ stage = 1, name = "Newborn",  model = "Koala Baby",      scale = 1.0, minAge = 0,    maxAge = 1200 }, -- 0-20 min
	{ stage = 2, name = "1 Year",   model = "Koala 1 year old",scale = 1.0, minAge = 1200, maxAge = 2400 }, -- 20-40 min
	{ stage = 3, name = "2 Year",   model = "Koala 2 year old",scale = 1.0, minAge = 2400, maxAge = 3600 }, -- 40-60 min
	{ stage = 4, name = "Adult",    model = "Koala",           scale = 1.0, minAge = 3600, maxAge = math.huge }, -- 60+ min
}

local ADULT_PROXIMITY_RADIUS = 15  -- Studs an adult must be within to count as "Protected"
local CUDDLE_BOOST_DURATION  = 180 -- 3 minutes of boosted growth after cuddle
local GROWTH_TICK_INTERVAL   = 5   -- Check every 5 seconds
local CUDDLE_SPEED_MULT      = 1.5 -- 1.5x growth speed during Cuddle Boost
local NORMAL_SPEED_MULT      = 1.0 -- 1.0x growth speed while Protected

-- Rarity configs
local RARITIES = {
	{ name = "Cute",       chance = 90, highlightColor = nil,                             particleColor = nil                          },
	{ name = "Extra Cute", chance = 8,  highlightColor = Color3.fromRGB(255, 200, 0),     particleColor = Color3.fromRGB(255, 215, 50) },
	{ name = "Ultra Cute", chance = 2,  highlightColor = Color3.fromRGB(200, 0, 255),     particleColor = Color3.fromRGB(255, 100, 255)},
}

local STAGE_REVENUE_MULTIPLIER = { 1.25, 1.0, 1.0, 1.0 }
local RARITY_REVENUE_MULTIPLIER = {
	["Cute"] = 1.0,
	["Extra Cute"] = 2.0,
	["Ultra Cute"] = 4.0
}

local KOALA_NAMES = {
	"Blinky", "Eucalyptus", "Joey", "Mochi", "Bluey", "Bondi", "Byron", "Noosa", 
	"Darwin", "Sydney", "Adelaide", "Perth", "Melba", "Rusty", "Bingo",
	"Bandit", "Chilli", "Cocoa", "Honey", "Sugar", "Marshmallow", "Waffles", "Pancake",
	"Nugget", "Tater", "Spud", "Pipsqueak", "Button", "Bubbles", "Pip", "Peanut",
	"Leafy", "Fern", "Moss", "Willow", "Cedar", "Ash", "Flora", "Berry", "Twig",
	"Scout", "Ranger", "Skipper", "Mate", "Cobber", "Boomer", "Digger", "Snickers",
	"Cuddles", "Snuggles", "Fuzzy", "Noodle", "Zippy", "Sleepy", "Kookaburra", "Wallaby",
	"Daintree", "Uluru", "Kakadu", "Coral", "Marley", "Ziggy", "Ozzie", "G'day"
}

-- ============================================================
-- HELPERS
-- ============================================================

function KoalaCoreManager.GetRandomName()
	local name = KOALA_NAMES[math.random(1, #KOALA_NAMES)]
	local suffixRoll = math.random(1, 100)
	if suffixRoll <= 15 then
		name = name .. " Jr."
	elseif suffixRoll <= 20 then
		name = name .. " III"
	end
	return name
end

local function getStageData(stage)
	return GROWTH_STAGES[stage] or GROWTH_STAGES[1]
end

local function getStageForAge(age)
	for i = #GROWTH_STAGES, 1, -1 do
		if age >= GROWTH_STAGES[i].minAge then
			return GROWTH_STAGES[i]
		end
	end
	return GROWTH_STAGES[1]
end

local function rollRarity()
	local roll = math.random(1, 100)
	local counter = 0
	for _, rarity in ipairs(RARITIES) do
		counter = counter + rarity.chance
		if roll <= counter then
			return rarity
		end
	end
	return RARITIES[1]
end

local function getKoalaStorageFolder()
	return ServerStorage:FindFirstChild("Koalas to pick from") or ServerStorage
end

local function getKoalaTemplate(modelName)
	local folder = getKoalaStorageFolder()
	local template = folder:FindFirstChild(modelName)
	if not template then
		warn("[KoalaCoreManager] Template not found: '" .. modelName .. "' in " .. folder:GetFullName())
	end
	return template
end

-- ============================================================
-- RARITY AURA
-- ============================================================

function KoalaCoreManager.ApplyRarityAura(koala, rarityName)
	-- Clear any existing aura first
	local existing = koala:FindFirstChild("RarityAura")
	if existing then existing:Destroy() end

	local config = nil
	for _, r in ipairs(RARITIES) do
		if r.name == rarityName then config = r break end
	end

	if not config or not config.highlightColor then return end -- "Cute" has no aura

	local auraFolder = Instance.new("Folder")
	auraFolder.Name = "RarityAura"
	auraFolder.Parent = koala

	-- Highlight glow
	local highlight = Instance.new("Highlight")
	highlight.Name = "GlowHighlight"
	highlight.FillTransparency = 0.85
	highlight.OutlineTransparency = 0.3
	highlight.FillColor = config.highlightColor
	highlight.OutlineColor = config.highlightColor
	highlight.Adornee = koala
	highlight.Parent = auraFolder

	-- Particle emitter for Ultra Cute
	if rarityName == "Ultra Cute" then
		-- Find the primary mesh part to attach particles to
		local meshPart = nil
		for _, desc in ipairs(koala:GetDescendants()) do
			if desc:IsA("MeshPart") or desc:IsA("Part") then
				meshPart = desc
				break
			end
		end

		if meshPart then
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = "HeartParticles"
			emitter.Color = ColorSequence.new(config.particleColor)
			emitter.LightEmission = 0.8
			emitter.LightInfluence = 0.2
			emitter.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(1, 0),
			})
			emitter.Lifetime = NumberRange.new(1.5, 2.5)
			emitter.Rate = 4
			emitter.Speed = NumberRange.new(2, 4)
			emitter.SpreadAngle = Vector2.new(30, 30)
			emitter.RotSpeed = NumberRange.new(-45, 45)
			emitter.Rotation = NumberRange.new(0, 360)
			emitter.Parent = meshPart
		end
	end

	print("[KoalaCoreManager] Applied '" .. rarityName .. "' aura to " .. koala.Name)
end

-- ============================================================
-- STAT INITIALIZATION
-- ============================================================

function KoalaCoreManager.InitKoala(koala, rarityName, startAge)
	-- Set up KoalaStats folder
	local stats = koala:FindFirstChild("KoalaStats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "KoalaStats"
		stats.Parent = koala
	end

	-- Age (seconds of active growth accumulated)
	local ageVal = stats:FindFirstChild("Age") or Instance.new("NumberValue")
	ageVal.Name = "Age"
	ageVal.Value = startAge or 0
	ageVal.Parent = stats

	-- Determine starting stage from age
	local stageData = getStageForAge(ageVal.Value)
	local stageVal = stats:FindFirstChild("Stage") or Instance.new("IntValue")
	stageVal.Name = "Stage"
	stageVal.Value = stageData.stage
	stageVal.Parent = stats

	-- Rarity
	local rarityVal = stats:FindFirstChild("Rarity") or Instance.new("StringValue")
	rarityVal.Name = "Rarity"
	rarityVal.Value = rarityName or "Cute"
	rarityVal.Parent = stats

	-- Cuddle time tracker
	local cuddleVal = stats:FindFirstChild("LastCuddleTime") or Instance.new("NumberValue")
	cuddleVal.Name = "LastCuddleTime"
	cuddleVal.Value = 0
	cuddleVal.Parent = stats

	-- Protected flag (managed by growth loop)
	local protectedVal = stats:FindFirstChild("IsProtected") or Instance.new("BoolValue")
	protectedVal.Name = "IsProtected"
	protectedVal.Value = false
	protectedVal.Parent = stats

	-- Set attributes for client access
	local currentName = koala:GetAttribute("DisplayName")
	if not currentName or currentName == "" or currentName == "Koala" then
		koala:SetAttribute("DisplayName", KoalaCoreManager.GetRandomName())
	end
	
	koala:SetAttribute("Age", ageVal.Value)
	koala:SetAttribute("MaxAge", stageData.maxAge)
	koala:SetAttribute("StageName", stageData.name)
	koala:SetAttribute("Stage", stageData.stage)
	koala:SetAttribute("Rarity", rarityVal.Value)
	koala:SetAttribute("RevenueMultiplier", KoalaCoreManager.GetRevenueMultiplier(koala))

	-- Apply rarity aura
	KoalaCoreManager.ApplyRarityAura(koala, rarityVal.Value)
	
	-- Global Shoutout for Ultra Cute
	if rarityVal.Value == "Ultra Cute" then
		task.spawn(function()
			local ReplicatedStorage = game:GetService("ReplicatedStorage")
			local remote = ReplicatedStorage:FindFirstChild("GlobalAnnounce")
			if not remote then
				remote = Instance.new("RemoteEvent", ReplicatedStorage)
				remote.Name = "GlobalAnnounce"
			end
			
			remote:FireAllClients("ðŸŒŸ A legendary **Ultra Cute** koala was just found! ðŸ¨âœ¨")
		end)
	end

	print(string.format("[KoalaCoreManager] Initialized %s | Stage %d (%s) | Rarity: %s | Age: %.0fs",
		koala.Name, stageData.stage, stageData.name, rarityVal.Value, ageVal.Value))
end

-- ============================================================
-- MODEL SWAP (Growth Transition)
-- ============================================================

function KoalaCoreManager.SwapModel(oldKoala, newStageName)
	local stageData = nil
	for _, s in ipairs(GROWTH_STAGES) do
		if s.name == newStageName then stageData = s break end
	end
	if not stageData then
		warn("[KoalaCoreManager] SwapModel: unknown stage name: " .. tostring(newStageName))
		return oldKoala
	end

	local template = getKoalaTemplate(stageData.model)
	if not template then
		warn("[KoalaCoreManager] SwapModel: No template for model '" .. stageData.model .. "'")
		return oldKoala
	end

	-- Capture current state from the old koala
	local oldStats   = oldKoala:FindFirstChild("KoalaStats")
	local oldAge     = oldStats and oldStats.Age.Value or 0
	local oldRarity  = oldStats and oldStats.Rarity.Value or "Cute"
	local oldName    = oldKoala:GetAttribute("DisplayName") or oldKoala.Name
	local hasNamed   = oldKoala:GetAttribute("HasBeenNamed") or false
	local homeExhibit = oldKoala:GetAttribute("HomeExhibit")
	local oldPos     = oldKoala:GetPivot()

	-- Spawn new model
	local newKoala = template:Clone()
	newKoala.Name = oldKoala.Name
	CollectionService:AddTag(newKoala, "KoalaNPC")

	-- Restore key attributes
	newKoala:SetAttribute("HomeExhibit", homeExhibit)
	newKoala:SetAttribute("DisplayName", oldName)
	newKoala:SetAttribute("HasBeenNamed", hasNamed)

	-- Parent into same location
	local targetParent = oldKoala.Parent or workspace
	newKoala.Parent = targetParent

	-- Place at the same position
	newKoala:PivotTo(oldPos)

	-- Init lifecycle stats on new model
	KoalaCoreManager.InitKoala(newKoala, oldRarity, oldAge)
	newKoala:SetAttribute("DisplayName", oldName)

	-- Remove old koala
	oldKoala:Destroy()

	print(string.format("[KoalaCoreManager] %s grew to %s! ðŸ¨", oldName, stageData.name))
	return newKoala
end

function KoalaCoreManager.RespawnAt(oldKoala, pos, parent)
	print("[KoalaCoreManager] RespawnAt triggered for " .. (oldKoala and oldKoala.Name or "nil"))
	local oldStats   = oldKoala:FindFirstChild("KoalaStats")
	local oldAge     = oldStats and oldStats.Age.Value or 0
	local oldRarity  = oldStats and oldStats.Rarity.Value or "Cute"
	local oldStage   = oldStats and oldStats.Stage.Value or 1
	local oldName    = oldKoala:GetAttribute("DisplayName") or oldKoala.Name
	local hasNamed   = oldKoala:GetAttribute("HasBeenNamed") or false
	local homeExhibit = parent and parent.Name or oldKoala:GetAttribute("HomeExhibit")

	-- Specific fix for KK rescue name
	if (oldKoala.Name == "KK" or oldName == "Koala") and not hasNamed then
		oldName = "KK"
	end

	local stageData = getStageData(oldStage)
	local template = getKoalaTemplate(stageData.model)
	if not template then return oldKoala end

	-- Spawn fresh
	local newKoala = template:Clone()
	newKoala.Name = oldKoala.Name
	CollectionService:AddTag(newKoala, "KoalaNPC")
	newKoala:SetAttribute("HomeExhibit", homeExhibit)
	newKoala:SetAttribute("DisplayName", oldName)
	newKoala:SetAttribute("HasBeenNamed", hasNamed)

	-- Parent to Workspace first (matches Dev Menu logic for stability)
	newKoala.Parent = workspace
	
	-- Position at the spawn point, offset by half HRP height to prevent clipping into terrain
	-- HRP is ~1.9 studs tall, so we need to spawn 0.95 studs above the surface
	local hrp = newKoala:FindFirstChild("HumanoidRootPart")
	local hrpHeight = hrp and hrp.Size.Y / 2 or 0.95
	newKoala:PivotTo(CFrame.new(pos + Vector3.new(0, hrpHeight, 0)))
	
	-- Parent to exhibit after positioning
	if parent then newKoala.Parent = parent end

	-- Init stats
	KoalaCoreManager.InitKoala(newKoala, oldRarity, oldAge)

	-- 3-Second "Sticky" Anchor to prevent falling through floor
	newKoala:SetAttribute("AI_Disabled", true)
	for _, p in pairs(newKoala:GetDescendants()) do
		if p:IsA("BasePart") then 
			p.Anchored = true 
			if p.Name == "HumanoidRootPart" then p.CanCollide = true end
		end
	end
	task.delay(3, function()
		if newKoala and newKoala.Parent then
			newKoala:SetAttribute("AI_Disabled", nil)
			for _, p in pairs(newKoala:GetDescendants()) do
				if p:IsA("BasePart") then p.Anchored = false end
			end
		end
	end)

	-- Cleanup old
	oldKoala:Destroy()
	return newKoala
end

-- ============================================================
-- GROWTH LOOP
-- ============================================================

local function isAdultNearby(babyPos)
	local tagged = CollectionService:GetTagged("KoalaNPC")
	for _, koala in ipairs(tagged) do
		if koala:IsDescendantOf(workspace) then
			local stats = koala:FindFirstChild("KoalaStats")
			local stageVal = stats and stats:FindFirstChild("Stage")
			if stageVal and stageVal.Value >= 4 then
				local hrp = koala:FindFirstChild("HumanoidRootPart")
				local pivot = hrp and hrp.Position or koala:GetPivot().Position
				if (babyPos - pivot).Magnitude <= ADULT_PROXIMITY_RADIUS then
					return true
				end
			end
		end
	end
	return false
end

local function growthTick()
	local allKoalas = CollectionService:GetTagged("KoalaNPC")
	for _, koala in ipairs(allKoalas) do
		if not koala:IsDescendantOf(workspace) then continue end
		if koala:GetAttribute("IsBeingCarried") then continue end

		local stats = koala:FindFirstChild("KoalaStats")
		if not stats then continue end

		local stageVal = stats:FindFirstChild("Stage")
		if not stageVal or stageVal.Value >= 4 then continue end

		local ageVal = stats:FindFirstChild("Age")
		local cuddleVal = stats:FindFirstChild("LastCuddleTime")
		local protectedVal = stats:FindFirstChild("IsProtected")
		if not ageVal then continue end

		local hrp = koala:FindFirstChild("HumanoidRootPart")
		local pivotPos = hrp and hrp.Position or koala:GetPivot().Position

		-- Check cuddle boost
		local cuddleActive = false
		if cuddleVal and cuddleVal.Value > 0 then
			cuddleActive = (os.time() - cuddleVal.Value) < CUDDLE_BOOST_DURATION
		end

		-- Check adult protection
		local protected = isAdultNearby(pivotPos)
		if protectedVal then protectedVal.Value = protected end

		if not protected and not cuddleActive then
			continue -- Stasis
		end

		-- Grow!
		local speedMult = cuddleActive and CUDDLE_SPEED_MULT or NORMAL_SPEED_MULT
		local newAge = ageVal.Value + (GROWTH_TICK_INTERVAL * speedMult)
		ageVal.Value = newAge

		-- Sync and check for growth
		KoalaCoreManager.RefreshGrowth(koala)
		
		-- Chance to show sleepy bubbles in growth loop as a backup
		if math.random() < 0.05 then
			KoalaCoreManager.ShowSleepyEffect(koala)
		end
	end
end

-- ============================================================
-- INITIALIZE
-- ============================================================

function KoalaCoreManager.Initialize()
	task.spawn(function()
		while true do
			task.wait(GROWTH_TICK_INTERVAL)
			local ok, err = pcall(growthTick)
			if not ok then
				warn("[KoalaCoreManager] Growth tick error: " .. tostring(err))
			end
		end
	end)
	
	-- Handle incoming KoalaActions
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local koalaAction = ReplicatedStorage:WaitForChild("KoalaAction")
	
	koalaAction.OnServerEvent:Connect(function(player, action, targetKoala)
		if not targetKoala or not targetKoala:IsDescendantOf(workspace) then return end
		
		if action == "Cuddle" then
			local stats = targetKoala:FindFirstChild("KoalaStats")
			if stats and stats:FindFirstChild("LastCuddleTime") then
				stats.LastCuddleTime.Value = os.time()
				print("[KoalaCoreManager] " .. player.Name .. " cuddled " .. targetKoala.Name)

				-- Show Heart Emoji Effect
				KoalaCoreManager.ShowHeartEffect(targetKoala)

				-- Start physical cuddle interaction via signal
				local signals = game:GetService("ServerStorage"):FindFirstChild("Signals")
				local requestCuddle = signals and signals:FindFirstChild("RequestCuddle")
				if requestCuddle then
					requestCuddle:Fire(player, targetKoala)
				else
					warn("[KoalaCoreManager] RequestCuddle signal not found!")
				end
			end
		elseif action == "Follow" then
			-- Clear any existing follower for this player
			for _, k in ipairs(CollectionService:GetTagged("KoalaNPC")) do
				if k:GetAttribute("FollowingPlayer") == player.Name then
					k:SetAttribute("FollowingPlayer", nil)
				end
			end
			targetKoala:SetAttribute("FollowingPlayer", player.Name)
			print("[KoalaCoreManager] " .. targetKoala.Name .. " is now following " .. player.Name)
			
		elseif action == "Stay" then
			targetKoala:SetAttribute("FollowingPlayer", nil)
			print("[KoalaCoreManager] " .. targetKoala.Name .. " is staying.")
		end
	end)

	-- Auto-init any koala that gets the KoalaNPC tag
	CollectionService:GetInstanceAddedSignal("KoalaNPC"):Connect(function(koala)
		task.wait(1)
		if not koala:IsDescendantOf(workspace) then return end
		if koala:FindFirstChild("KoalaStats") then return end
		-- KK and other legacy koalas default to Adult (Cute)
		KoalaCoreManager.InitKoala(koala, "Cute", 3600)
	end)

	-- Handle RequestRespawn
	local signalsFolder = ServerStorage:WaitForChild("Signals")
	local requestRespawn = signalsFolder:FindFirstChild("RequestRespawn")
	if requestRespawn then
		requestRespawn.Event:Connect(function(oldKoala, pos, parent)
			KoalaCoreManager.RespawnAt(oldKoala, pos, parent)
		end)
	end

	print("[KoalaCoreManager] Initialized. Growth tick every " .. GROWTH_TICK_INTERVAL .. "s.")
end

-- ============================================================
-- PUBLIC API
-- ============================================================

function KoalaCoreManager.ShowHeartEffect(target)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HeartPopup"
	billboard.Size = UDim2.new(2, 0, 2, 0)
	billboard.Adornee = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChildOfClass("Part")
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = target
	
	local label = Instance.new("TextLabel", billboard)
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "â¤ï¸"
	label.TextScaled = true
	
	-- Animation: float up and fade
	task.spawn(function()
		for i = 0, 20 do
			if not billboard or not label then break end
			billboard.StudsOffset = billboard.StudsOffset + Vector3.new(0, 0.1, 0)
			label.TextTransparency = i / 20
			task.wait(0.05)
		end
		if billboard then billboard:Destroy() end
	end)
end

function KoalaCoreManager.ShowSleepyEffect(target)
	local hrp = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChildOfClass("Part")
	if not hrp then return end
	
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SleepyPopup"
	billboard.Size = UDim2.new(2, 0, 2, 0)
	billboard.Adornee = hrp
	billboard.StudsOffset = Vector3.new(1, 2, 0) -- Slightly offset to side
	billboard.AlwaysOnTop = true
	billboard.Parent = target
	
	local label = Instance.new("TextLabel", billboard)
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "ðŸ’¤"
	label.TextScaled = true
	label.Rotation = -15
	
	-- Animation: float up, grow, and fade
	task.spawn(function()
		for i = 0, 30 do
			if not billboard or not label then break end
			billboard.StudsOffset = billboard.StudsOffset + Vector3.new(0.05, 0.08, 0)
			label.TextTransparency = i / 30
			label.Rotation = label.Rotation + 1
			task.wait(0.05)
		end
		if billboard then billboard:Destroy() end
	end)
end

function KoalaCoreManager.RefreshGrowth(koala)
	local stats = koala:FindFirstChild("KoalaStats")
	if not stats then return end
	
	local ageVal = stats:FindFirstChild("Age")
	local stageVal = stats:FindFirstChild("Stage")
	if not ageVal or not stageVal then return end

	local currentStage = stageVal.Value
	local stageData = getStageForAge(ageVal.Value)
	
	-- Update attributes
	koala:SetAttribute("Age", ageVal.Value)
	koala:SetAttribute("MaxAge", stageData.maxAge)
	koala:SetAttribute("StageName", stageData.name)
	koala:SetAttribute("Stage", stageData.stage)
	koala:SetAttribute("RevenueMultiplier", KoalaCoreManager.GetRevenueMultiplier(koala))

	-- Check for growth
	if stageData.stage > currentStage then
		KoalaCoreManager.SwapModel(koala, stageData.name)
	end
end

function KoalaCoreManager.GetRevenueMultiplier(koala)
	local stats = koala:FindFirstChild("KoalaStats")
	if not stats then return 1.0 end
	
	local stageVal = stats:FindFirstChild("Stage")
	local rarityVal = stats:FindFirstChild("Rarity")
	
	local stage = stageVal and stageVal.Value or 4
	local rarity = rarityVal and rarityVal.Value or "Cute"
	
	local stageMult = STAGE_REVENUE_MULTIPLIER[stage] or 1.0
	local rarityMult = RARITY_REVENUE_MULTIPLIER[rarity] or 1.0
	
	return stageMult * rarityMult
end

function KoalaCoreManager.RollRarity()
	return rollRarity()
end

function KoalaCoreManager.GetStageName(stage)
	return GROWTH_STAGES[stage] and GROWTH_STAGES[stage].name or "Unknown"
end

return KoalaCoreManager
]==]
local cs_content = [==[local CarryService = {}
-- local KoalaCoreManager = require(game:GetService("ServerScriptService").Services.KoalaCoreManager) -- Removed for Decoupling
function CarryService.Initialize()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local koalaAction = ReplicatedStorage:WaitForChild("KoalaAction")
	
	koalaAction.OnServerEvent:Connect(function(player, action, targetKoala)
		if action == "Carry" then
			CarryService.PickUp(player, targetKoala)
		elseif action == "Drop" then
			local char = player.Character
			if char and char:FindFirstChild("HumanoidRootPart") then
				-- Drop in front of player, slightly down
				local dropPos = char.HumanoidRootPart.CFrame * CFrame.new(0, -1.5, -3)
				CarryService.Drop(player, dropPos)
			end
		end
	end)

	-- Handle RequestCuddle
	local signals = game:GetService("ServerStorage"):FindFirstChild("Signals")
	local requestCuddle = signals and signals:FindFirstChild("RequestCuddle")
	if requestCuddle then
		requestCuddle.Event:Connect(function(player, koala)
			CarryService.PerformCuddle(player, koala)
		end)
	end
	print("[CarryService] Initialized.")
end
local function setArms(player, hold)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChild("Humanoid")
	if not hum then return end
	
	local function updateMotor(motor, targetC0)
		if motor and motor:IsA("Motor6D") then
			pcall(function()
				motor.C0 = targetC0
			end)
		end
	end
	local isR15 = hum.RigType == Enum.HumanoidRigType.R15
	if isR15 then
		local rArm = char:FindFirstChild("RightUpperArm")
		local lArm = char:FindFirstChild("LeftUpperArm")
		if rArm and lArm then
			updateMotor(rArm:FindFirstChild("RightShoulder"), hold and CFrame.new(1, 0.5, 0) * CFrame.Angles(math.rad(60), 0, math.rad(-20)) or CFrame.new(1, 0.5, 0))
			updateMotor(lArm:FindFirstChild("LeftShoulder"), hold and CFrame.new(-1, 0.5, 0) * CFrame.Angles(math.rad(60), 0, math.rad(20)) or CFrame.new(-1, 0.5, 0))
		end
	else
		-- R6
		local tor = char:FindFirstChild("Torso")
		if tor then
			updateMotor(tor:FindFirstChild("Right Shoulder"), hold and CFrame.new(1, 0.5, 0) * CFrame.Angles(0, math.rad(90), math.rad(70)) or CFrame.new(1, 0.5, 0))
			updateMotor(tor:FindFirstChild("Left Shoulder"), hold and CFrame.new(-1, 0.5, 0) * CFrame.Angles(0, math.rad(-90), math.rad(-70)) or CFrame.new(-1, 0.5, 0))
		end
	end
end
function CarryService.PickUp(player, targetModel, weldTarget, isCuddle)
	print("[CarryService] PickUp called for " .. player.Name .. " target: " .. (targetModel and targetModel.Name or "nil"))
	local character = player.Character
	if not character then 
		print("[CarryService] âŒ No character found for " .. player.Name)
		return 
	end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChild("Humanoid")
	if not rootPart or not humanoid then 
		print("[CarryService] âŒ Missing rootPart or humanoid")
		return 
	end
	
	-- Force unequip other tools
	humanoid:UnequipTools()
	
	-- Rotate Arms
	pcall(function() setArms(player, true) end)
	
	-- Disable target AI/Physics
	targetModel:SetAttribute("AI_Disabled", true)
	local targetRoot = targetModel:FindFirstChild("HumanoidRootPart") or targetModel:FindFirstChildOfClass("Part")
	if not targetRoot then 
		print("[CarryService] âŒ No root part found for target model")
		return 
	end
	
	-- Position target
	if weldTarget then
		targetModel:PivotTo(weldTarget.CFrame)
	elseif isCuddle then
		-- Centered "Hug" Position
		targetModel:PivotTo(rootPart.CFrame * CFrame.new(0, -0.2, -0.7) * CFrame.Angles(0, math.rad(180), 0))
	else
		-- Side-Carry Position: Lower, to the right, and rotated 90 degrees
		targetModel:PivotTo(rootPart.CFrame * CFrame.new(0.7, -0.4, -0.6) * CFrame.Angles(0, math.rad(90), 0))
	end
	
	print("[CarryService] Parts setup starting...")
	-- Make parts ghost-like and weightless
	for _, p in pairs(targetModel:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.Massless = true
			p.Anchored = false
			-- Ensure visible
			p.Transparency = 0
			if p.Name == "HumanoidRootPart" then p.Transparency = 1 end
			
			-- If in a crate, maybe hide or shrink (optional visual flavor)
			if weldTarget then
				-- p.Transparency = 1
				if p.Name == "SelectionBox" then p:Destroy() end
			end
		elseif p:IsA("Decal") or p:IsA("Texture") then
			-- if weldTarget then p.Transparency = 1 end
		end
	end
	
	print("--- " .. player.Name .. " PICKED UP " .. targetModel.Name .. " ---")
	
	-- Create Weld
	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = weldTarget or rootPart
	weld.Part1 = targetRoot
	weld.Parent = targetRoot
	
	-- Disable target physics
	local targetHum = targetModel:FindFirstChild("Humanoid")
	if targetHum then
		targetHum.PlatformStand = true
	end
	
	player:SetAttribute("Carrying", targetModel.Name)
	targetModel:SetAttribute("IsBeingCarried", true)
	targetModel:SetAttribute("FollowingPlayer", nil) -- Clear follower status when picked up
	if weldTarget then
		targetModel:SetAttribute("Crated", true)
	end
end
function CarryService.PerformCuddle(player, koala)
	local char = player.Character
	local hum = char and char:FindFirstChild("Humanoid")
	if not hum then return end
	
	-- Root player
	local oldSpeed = hum.WalkSpeed
	local oldJump = hum.JumpPower
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	
	-- Pick up in "Cuddle" position
	CarryService.PickUp(player, koala, nil, true)
	
	task.wait(2)
	
	-- Drop
	local dropPos = char.HumanoidRootPart.CFrame * CFrame.new(0, -1.5, -1.5)
	CarryService.Drop(player, dropPos)
	
	-- Restore player
	hum.WalkSpeed = oldSpeed
	hum.JumpPower = oldJump
end
function CarryService.Drop(player, dropCFrame, explicitExhibitName)
	local character = player.Character
	if not character then return end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local carryingName = player:GetAttribute("Carrying")
	if not carryingName then return end
	
	-- Find the carried model in the workspace by checking attribute
	local targetModel = nil
	for _, m in pairs(workspace:GetDescendants()) do
		if m:IsA("Model") and m.Name == carryingName and m:GetAttribute("IsBeingCarried") then
			targetModel = m
			break
		end
	end
	
	if targetModel then
		-- 1. Identify Exhibit First
		local exhibitName = explicitExhibitName
		local dropParent = nil
		
		-- If client didn't send explicit name, fallback to spatial search
		if not exhibitName then
			for _, obj in pairs(workspace:GetDescendants()) do
				if obj.Name == "Ground" and (obj.Position - dropCFrame.Position).Magnitude < 25 then
					exhibitName = obj.Parent.Name
					dropParent = obj.Parent
					break
				end
			end
		else
			dropParent = workspace:FindFirstChild(exhibitName)
		end
		
		-- 2. Validate Exhibit State (Safety Check)
		if exhibitName and dropParent then
			if not dropParent:GetAttribute("IsRepaired") then
				local playerGui = player:FindFirstChild("PlayerGui")
				local tutorialUI = playerGui and playerGui:FindFirstChild("TutorialUI")
				local statusLabel = tutorialUI and tutorialUI:FindFirstChild("Status")
				if statusLabel then
					statusLabel.Text = "âš ï¸ You must repair the exhibit before placing koalas!"
					statusLabel.Visible = true
					task.delay(5, function() statusLabel.Visible = false end)
				end
				return -- EXIT: Keep koala in inventory/crate
			end
		end
		-- Clean Arms
		pcall(function() setArms(player, false) end)
		player:SetAttribute("Carrying", nil)
		-- Clean Respawn!
		-- Find a nice spawn point (center of exhibit if possible)
		local spawnPos = dropCFrame.Position
		if dropParent and dropParent:FindFirstChild("Ground") then
			local g = dropParent.Ground
			
			-- Raycast to find the true terrain/surface height
			local rayOrigin = Vector3.new(g.Position.X, g.Position.Y + 50, g.Position.Z)
			local rayDirection = Vector3.new(0, -100, 0)
			
			local rayParams = RaycastParams.new()
			-- Exclude the dropping player and the carried model
			rayParams.FilterDescendantsInstances = {player.Character, targetModel}
			rayParams.FilterType = Enum.RaycastFilterType.Exclude
			
			local result = workspace:Raycast(rayOrigin, rayDirection, rayParams)
			if result then
				spawnPos = result.Position
			else
				-- Fallback if raycast fails
				spawnPos = Vector3.new(g.Position.X, g.Position.Y + (g.Size.Y / 2), g.Position.Z)
			end
		end
		local signals = game:GetService("ServerStorage"):FindFirstChild("Signals")
		local requestRespawn = signals and signals:FindFirstChild("RequestRespawn")
		if requestRespawn then
			print("[CarryService] Firing RequestRespawn for " .. targetModel.Name)
			requestRespawn:Fire(targetModel, spawnPos, dropParent)
		else
			warn("[CarryService] RequestRespawn signal not found!")
		end
		
		-- Tutorial Reward Logic
		if exhibitName == "TutorialExhibit_Workspace" and carryingName == "KK" then
			local hasExhibit = player:FindFirstChild("HasExhibit")
			
			-- Always fire quest update and clear it, to prevent stuck UI
			local signals = game:GetService("ServerStorage"):FindFirstChild("Signals")
			if signals and signals:FindFirstChild("UpdateQuest") then
				signals.UpdateQuest:Fire(player, "ðŸŽ‰ KK is Home! You completed the first rescue!")
				
				-- Clear quest after 8 seconds (longer for first one)
				task.delay(8, function()
					signals.UpdateQuest:Fire(player, "")
				end)
			end
			
			-- Reward only if first time
			if hasExhibit and not hasExhibit.Value then
				local signals = game:GetService("ServerStorage"):FindFirstChild("Signals")
				local grantCurrency = signals and signals:FindFirstChild("GrantCurrency")
				if grantCurrency then
					grantCurrency:Fire(player, 500, "Cash")
				else
					leaderstats.Cash.Value += 500
				end
				hasExhibit.Value = true
				print("Reward given and Exhibit Owned by " .. player.Name)
			end
		end
	end
end
return CarryService
]==]

game:GetService("ServerScriptService").Services.KoalaCoreManager.Source = km_content
game:GetService("ServerScriptService").Services.CarryService.Source = cs_content
print("Synced KoalaCoreManager and CarryService to Studio")
