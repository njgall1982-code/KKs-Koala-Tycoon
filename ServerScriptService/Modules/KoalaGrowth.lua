local KoalaGrowth = {}

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local KoalaConfig    = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("KoalaConfig"))
local KoalaVFX       = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("KoalaVFX"))
local KoalaLifecycle = require(ServerScriptService:WaitForChild("Modules"):WaitForChild("KoalaLifecycle"))

-- ============================================================
-- HELPERS
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
				if (babyPos - pivot).Magnitude <= KoalaConfig.ADULT_PROXIMITY_RADIUS then
					return true
				end
			end
		end
	end
	return false
end

function KoalaGrowth.RefreshGrowth(koala)
	local stats = koala:FindFirstChild("KoalaStats")
	if not stats then return end

	local ageVal = stats:FindFirstChild("Age")
	local stageVal = stats:FindFirstChild("Stage")
	if not ageVal or not stageVal then return end

	local currentStage = stageVal.Value
	local age = ageVal.Value
	local stageData = KoalaConfig.GetStageForAge(age)
	local nextStageData = KoalaConfig.GROWTH_STAGES[stageData.stage + 1]

	-- Update attributes for UI
	koala:SetAttribute("Age", age)
	koala:SetAttribute("StageName", stageData.name)
	koala:SetAttribute("StageMin", stageData.minAge)
	koala:SetAttribute("StageMax", nextStageData and nextStageData.minAge or stageData.minAge)
	koala:SetAttribute("Stage", stageData.stage)
	koala:SetAttribute("IsAdult", stageData.stage >= 4)
	koala:SetAttribute("RevenueMultiplier", KoalaConfig.GetRevenueMultiplier(koala))

	-- Update growth status label
	KoalaGrowth.UpdateGrowthStatus(koala)

	-- Check for growth
	if stageData.stage > currentStage then
		local dName = koala:GetAttribute("DisplayName") or koala.Name
		print("[KoalaGrowth] " .. dName .. " is growing! Stage " .. currentStage .. " -> " .. stageData.stage)
		
		-- Update the IntValue before swapping to ensure parity
		stageVal.Value = stageData.stage
		
		KoalaLifecycle.SwapModel(koala, stageData.name)
	end
end

function KoalaGrowth.UpdateGrowthStatus(koala)
	local lastCuddle = koala:GetAttribute("LastCuddleTime") or 0
	local cuddleActive = (workspace:GetServerTimeNow() - lastCuddle) < KoalaConfig.CUDDLE_BOOST_DURATION

	local hrp = koala:FindFirstChild("HumanoidRootPart")
	local pivotPos = hrp and hrp.Position or koala:GetPivot().Position
	
	-- Only babies/teens need protection
	local isAdult = koala:GetAttribute("IsAdult")
	local protected = false
	if not isAdult then
		protected = isAdultNearby(pivotPos)
	end

	local status = "🐌 Growing Slow (0.2x)"
	local speedMult = KoalaConfig.BACKGROUND_SPEED_MULT

	if isAdult then
		status = "✅ Fully Grown!"
		speedMult = 0
	elseif cuddleActive then
		speedMult = KoalaConfig.CUDDLE_SPEED_MULT
		status = "⚡ Cuddle Boosted! (" .. speedMult .. "x)"
	elseif protected then
		speedMult = KoalaConfig.NORMAL_SPEED_MULT
		status = "🏘️ Growing Protected (" .. speedMult .. "x)"
	end

	koala:SetAttribute("GrowthStatus", status)
	return speedMult
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
		if not ageVal then continue end

		-- Update status and get multiplier
		local speedMult = KoalaGrowth.UpdateGrowthStatus(koala)

		-- Grow!
		local newAge = ageVal.Value + (KoalaConfig.GROWTH_TICK_INTERVAL * speedMult)
		ageVal.Value = newAge

		-- Sync and check
		KoalaGrowth.RefreshGrowth(koala)

		-- Sleepy effect
		if math.random() < 0.05 then
			KoalaVFX.ShowSleepyEffect(koala)
		end
	end
end

function KoalaGrowth.Initialize()
	task.spawn(function()
		while true do
			task.wait(KoalaConfig.GROWTH_TICK_INTERVAL)
			local ok, err = pcall(growthTick)
			if not ok then
				warn("[KoalaGrowth] Growth tick error: " .. tostring(err))
			end
		end
	end)
end

return KoalaGrowth
