local KoalaLifecycle = {}

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

	-- Spawn new model
	local newKoala = template:Clone()
	newKoala.Name = oldKoala.Name
	CollectionService:AddTag(newKoala, "KoalaNPC")

	-- Restore attributes
	newKoala:SetAttribute("HomeExhibit", homeExhibit)
	newKoala:SetAttribute("DisplayName", oldName)
	newKoala:SetAttribute("HasBeenNamed", hasNamed)

	newKoala.Parent = oldKoala.Parent or workspace
	newKoala:PivotTo(oldPos)

	-- Init lifecycle stats
	KoalaLifecycle.InitKoala(newKoala, oldRarity, oldAge)
	newKoala:SetAttribute("DisplayName", oldName)

	-- Cleanup
	oldKoala:Destroy()

	-- Notify clients
	local inspectRemote = ReplicatedStorage:FindFirstChild("InspectKoala")
	if inspectRemote then
		inspectRemote:FireAllClients(newKoala)
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

	newKoala.Parent = workspace

	local hrp = newKoala:FindFirstChild("HumanoidRootPart")
	local hrpHeight = hrp and hrp.Size.Y / 2 or 0.95
	newKoala:PivotTo(CFrame.new(pos + Vector3.new(0, hrpHeight, 0)))

	if parent then 
		newKoala.Parent = parent 
		newKoala:SetAttribute("HomeExhibit", parent.Name)
	end

	KoalaLifecycle.InitKoala(newKoala, oldRarity, oldAge)

	-- Sticky Anchor
	newKoala:SetAttribute("AI_Disabled", true)
	for _, p in pairs(newKoala:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = true end
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
