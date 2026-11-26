local KoalaLifecycle = {}

local Log = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Log"))
local Net = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Net"))

local CollectionService = game:GetService("CollectionService")
local ServerStorage    = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local KoalaConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("KoalaConfig"))
local KoalaVFX    = require(game:GetService("ServerScriptService"):WaitForChild("Modules"):WaitForChild("KoalaVFX"))

-- ============================================================
-- HELPERS
-- ============================================================

local function getKoalaStorageFolder()
	return ServerStorage:FindFirstChild("Koalas to pick from") or ServerStorage
end

local function getKoalaTemplate(modelName)
	local folder = getKoalaStorageFolder()
	local template = folder:FindFirstChild(modelName)
	if not template then
		warn("[KoalaLifecycle] Template not found: '" .. modelName .. "' in " .. folder:GetFullName())
	end
	return template
end

-- ============================================================
-- STAT INITIALIZATION
-- ============================================================

function KoalaLifecycle.InitKoala(koala, rarityName, startAge)
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
	local stageData = KoalaConfig.GetStageForAge(ageVal.Value)
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

	-- Protected flag
	local protectedVal = stats:FindFirstChild("IsProtected") or Instance.new("BoolValue")
	protectedVal.Name = "IsProtected"
	protectedVal.Value = false
	protectedVal.Parent = stats

	-- Set attributes for client access
	local currentName = koala:GetAttribute("DisplayName")
	if not currentName or currentName == "" or currentName == "Koala" then
		koala:SetAttribute("DisplayName", KoalaConfig.GetRandomName())
	end

	koala:SetAttribute("Age", ageVal.Value)
	koala:SetAttribute("MaxAge", stageData.maxAge)
	koala:SetAttribute("StageName", stageData.name)
	koala:SetAttribute("Stage", stageData.stage)
	koala:SetAttribute("Rarity", rarityVal.Value)
	koala:SetAttribute("RevenueMultiplier", KoalaConfig.GetRevenueMultiplier(koala))

	-- Apply rarity aura
	KoalaVFX.ApplyRarityAura(koala, rarityVal.Value)

	-- Instant Bone Initialization: Ensure zero delay/contortion on spawn
	Net.Signal("InitKoalaAI"):Fire(koala)
end

function KoalaLifecycle.SwapModel(oldKoala, newStageName)
	local stageData = nil
	for _, s in ipairs(KoalaConfig.GROWTH_STAGES) do
		if s.name == newStageName then stageData = s break end
	end
	if not stageData then
		warn("[KoalaLifecycle] SwapModel: unknown stage name: " .. tostring(newStageName))
		return oldKoala
	end

	local template = getKoalaTemplate(stageData.model)
	if not template then
		warn("[KoalaLifecycle] SwapModel: No template for model '" .. stageData.model .. "'")
		return oldKoala
	end

	-- Capture current state
	local oldStats   = oldKoala:FindFirstChild("KoalaStats")
	local oldAge     = oldStats and oldStats.Age.Value or 0
	local oldRarity  = oldStats and oldStats.Rarity.Value or "Cute"
	local oldName    = oldKoala:GetAttribute("DisplayName") or oldKoala.Name
	local hasNamed   = oldKoala:GetAttribute("HasBeenNamed") or false
	local homeExhibit = oldKoala:GetAttribute("HomeExhibit")
	local oldPos     = oldKoala:GetPivot()
	local oldHat = oldKoala:GetAttribute("EquippedOutfit_Hat") or oldKoala:GetAttribute("EquippedOutfit") or ""
	local oldNeck = oldKoala:GetAttribute("EquippedOutfit_Necklace") or ""

	-- Debug (enable with ReplicatedStorage attribute DebugLogs = true)
	Log.debug("KoalaLifecycle.SwapModel", "growth: old HRP Y=%s | old pivot Y=%s | template WorldPivot Y=%s",
		tostring(oldKoala:FindFirstChild("HumanoidRootPart") and oldKoala.HumanoidRootPart.Position.Y),
		tostring(oldPos.Position.Y), tostring(template.WorldPivot.Position.Y))

	-- Spawn new model
	local newKoala = template:Clone()
	newKoala.Name = oldKoala.Name
	CollectionService:AddTag(newKoala, "KoalaNPC")

	-- Restore attributes
	newKoala:SetAttribute("HomeExhibit", homeExhibit)
	newKoala:SetAttribute("DisplayName", oldName)
	newKoala:SetAttribute("HasBeenNamed", hasNamed)

	-- Sticky Anchor BEFORE parenting and initializing to prevent falling on first frame
	newKoala:SetAttribute("AI_Disabled", true)
	for _, p in pairs(newKoala:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = true end
	end

	newKoala.Parent = oldKoala.Parent or workspace
	
	Log.debug("KoalaLifecycle.SwapModel", "new HRP before PivotTo Y=%s", tostring(newKoala:FindFirstChild("HumanoidRootPart").Position.Y))
	
	newKoala:PivotTo(oldPos)
	
	Log.debug("KoalaLifecycle.SwapModel", "new HRP after PivotTo Y=%s", tostring(newKoala:FindFirstChild("HumanoidRootPart").Position.Y))

	-- Init lifecycle stats
	KoalaLifecycle.InitKoala(newKoala, oldRarity, oldAge)
	newKoala:SetAttribute("DisplayName", oldName)

	-- Re-equip outfits if this is now an adult
	local newStage = newKoala:GetAttribute("Stage") or 1
	if newStage == 4 then
		if oldHat ~= "" then
			Net.Signal("EquipOutfit"):Fire(newKoala, oldHat)
		end
		if oldNeck ~= "" then
			Net.Signal("EquipOutfit"):Fire(newKoala, oldNeck)
		end
	else
		newKoala:SetAttribute("EquippedOutfit_Hat", nil)
		newKoala:SetAttribute("EquippedOutfit_Necklace", nil)
		newKoala:SetAttribute("EquippedOutfit", nil)
	end

	-- Release Sticky Anchor after a short delay
	task.delay(3, function()
		if newKoala and newKoala.Parent then
			newKoala:SetAttribute("AI_Disabled", nil)
			for _, p in pairs(newKoala:GetDescendants()) do
				if p:IsA("BasePart") then p.Anchored = false end
			end
		end
	end)

	-- Cleanup
	oldKoala:Destroy()

	-- Notify clients
	local inspectRemote = ReplicatedStorage:FindFirstChild("InspectKoala")
	if inspectRemote then
		inspectRemote:FireAllClients(newKoala, true)
	end

	print(string.format("[KoalaLifecycle] %s grew to %s! 🐨", oldName, stageData.name))
	return newKoala
end

function KoalaLifecycle.RespawnAt(oldKoala, pos, parent)
	print("[KoalaLifecycle] RespawnAt triggered for " .. (oldKoala and oldKoala.Name or "nil"))
	local oldStats   = oldKoala:FindFirstChild("KoalaStats")
	local oldAge     = oldStats and oldStats.Age.Value or 0
	local oldRarity  = oldStats and oldStats.Rarity.Value or "Cute"
	local oldStage   = oldStats and oldStats.Stage.Value or (oldKoala.Name == "KK" and 4 or 1)
	local oldName    = oldKoala:GetAttribute("DisplayName") or oldKoala.Name
	local hasNamed   = oldKoala:GetAttribute("HasBeenNamed") or false
	local homeExhibit = parent and parent.Name or oldKoala:GetAttribute("HomeExhibit")
	local oldHat = oldKoala:GetAttribute("EquippedOutfit_Hat") or oldKoala:GetAttribute("EquippedOutfit") or ""
	local oldNeck = oldKoala:GetAttribute("EquippedOutfit_Necklace") or ""

	if (oldKoala.Name == "KK" or oldName == "Koala") and not hasNamed then
		oldName = "KK"
	end

	local stageData = KoalaConfig.GetStageData(oldStage)
	local template = getKoalaTemplate(stageData.model)
	if not template then return oldKoala end

	local newKoala = template:Clone()
	newKoala.Name = oldKoala.Name
	CollectionService:AddTag(newKoala, "KoalaNPC")
	newKoala:SetAttribute("HomeExhibit", homeExhibit)
	newKoala:SetAttribute("DisplayName", oldName)
	newKoala:SetAttribute("HasBeenNamed", hasNamed)

	-- Sticky Anchor BEFORE parenting and initializing to prevent falling or exploding on first frame
	newKoala:SetAttribute("AI_Disabled", true)
	for _, p in pairs(newKoala:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = true end
	end

	newKoala.Parent = workspace

	-- Position koala at the spawn point
	-- The mesh PivotOffset already accounts for visual positioning
	
	Log.debug("KoalaLifecycle.RespawnAt", "template WorldPivot Y=%s | spawn Y=%s | HRP before PivotTo Y=%s",
		tostring(template.WorldPivot.Position.Y), tostring(pos.Y), tostring(newKoala:FindFirstChild("HumanoidRootPart").Position.Y))
	
	newKoala:PivotTo(CFrame.new(pos))
	
	Log.debug("KoalaLifecycle.RespawnAt", "HRP after PivotTo Y=%s | model pivot Y=%s",
		tostring(newKoala:FindFirstChild("HumanoidRootPart").Position.Y), tostring(newKoala:GetPivot().Position.Y))

	if parent then 
		newKoala.Parent = parent 
		newKoala:SetAttribute("HomeExhibit", parent.Name)
	end

	KoalaLifecycle.InitKoala(newKoala, oldRarity, oldAge)

	-- Re-equip outfits if this is an adult
	local newStage = newKoala:GetAttribute("Stage") or 1
	if newStage == 4 then
		if oldHat ~= "" then
			Net.Signal("EquipOutfit"):Fire(newKoala, oldHat)
		end
		if oldNeck ~= "" then
			Net.Signal("EquipOutfit"):Fire(newKoala, oldNeck)
		end
	else
		newKoala:SetAttribute("EquippedOutfit_Hat", nil)
		newKoala:SetAttribute("EquippedOutfit_Necklace", nil)
		newKoala:SetAttribute("EquippedOutfit", nil)
	end

	task.delay(3, function()
		if newKoala and newKoala.Parent then
			newKoala:SetAttribute("AI_Disabled", nil)
			for _, p in pairs(newKoala:GetDescendants()) do
				if p:IsA("BasePart") then p.Anchored = false end
			end
		end
	end)

	oldKoala:Destroy()
	return newKoala
end

return KoalaLifecycle
