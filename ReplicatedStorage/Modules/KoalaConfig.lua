local KoalaConfig = {}

-- ============================================================
-- GROWTH CONFIG
-- ============================================================

-- Growth time thresholds in SECONDS of "active" growth time.
KoalaConfig.GROWTH_STAGES = {
	-- { Stage, Name, ModelName, Scale, MinAge (seconds active), MaxAge }
	{ stage = 1, name = "Newborn",  model = "Koala Baby",      scale = 1.0, minAge = 0,    maxAge = 30 }, 
	{ stage = 2, name = "1 Year",   model = "Koala 1 year old",scale = 1.0, minAge = 30,   maxAge = 60 }, 
	{ stage = 3, name = "2 Year",   model = "Koala 2 year old",scale = 1.0, minAge = 60,   maxAge = 90 }, 
	{ stage = 4, name = "Adult",    model = "Koala",           scale = 1.0, minAge = 90,   maxAge = math.huge }, 
}

KoalaConfig.ADULT_PROXIMITY_RADIUS = 50
KoalaConfig.CUDDLE_BOOST_DURATION  = 180 -- 3 minutes boost
KoalaConfig.GROWTH_TICK_INTERVAL   = 5
KoalaConfig.CUDDLE_SPEED_MULT      = 1.5
KoalaConfig.NORMAL_SPEED_MULT      = 1.0
KoalaConfig.BACKGROUND_SPEED_MULT  = 0.2

-- ============================================================
-- RARITY CONFIG
-- ============================================================

KoalaConfig.RARITIES = {
	{ name = "Cute",       chance = 90, highlightColor = nil,                             particleColor = nil                          },
	{ name = "Extra Cute", chance = 8,  highlightColor = Color3.fromRGB(255, 200, 0),     particleColor = Color3.fromRGB(255, 215, 50) },
	{ name = "Ultra Cute", chance = 2,  highlightColor = Color3.fromRGB(200, 0, 255),     particleColor = Color3.fromRGB(255, 100, 255)},
}

-- Base revenue generated per 5-second tick by stage
KoalaConfig.STAGE_BASE_REVENUE = {
	[1] = 10, -- Newborn ($10/cycle)
	[2] = 18, -- 1 Year  ($18/cycle)
	[3] = 28, -- 2 Year  ($28/cycle)
	[4] = 42, -- Adult   ($42/cycle)
}
-- Legacy multiplier mapping (maintaining backwards compatibility)
KoalaConfig.STAGE_REVENUE_MULTIPLIER = { 0.4, 0.72, 1.12, 1.68 }

KoalaConfig.RARITY_REVENUE_MULTIPLIER = {
	["Cute"] = 1.0,
	["Extra Cute"] = 2.0,
	["Ultra Cute"] = 4.5
}

-- ============================================================
-- NAME CONFIG
-- ============================================================

KoalaConfig.KOALA_NAMES = {
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

function KoalaConfig.GetRandomName()
	local name = KoalaConfig.KOALA_NAMES[math.random(1, #KoalaConfig.KOALA_NAMES)]
	local suffixRoll = math.random(1, 100)
	if suffixRoll <= 15 then
		name = name .. " Jr."
	elseif suffixRoll <= 20 then
		name = name .. " III"
	end
	return name
end

function KoalaConfig.GetStageData(stage)
	return KoalaConfig.GROWTH_STAGES[stage] or KoalaConfig.GROWTH_STAGES[1]
end

function KoalaConfig.GetStageForAge(age)
	for i = #KoalaConfig.GROWTH_STAGES, 1, -1 do
		if age >= KoalaConfig.GROWTH_STAGES[i].minAge then
			return KoalaConfig.GROWTH_STAGES[i]
		end
	end
	return KoalaConfig.GROWTH_STAGES[1]
end

function KoalaConfig.RollRarity()
	local roll = math.random(1, 100)
	local counter = 0
	for _, rarity in ipairs(KoalaConfig.RARITIES) do
		counter = counter + rarity.chance
		if roll <= counter then
			return rarity
		end
	end
	return KoalaConfig.RARITIES[1]
end

-- ============================================================
-- HAPPINESS EVALUATION
-- ============================================================

-- Calculates 0-100% happiness score for a koala in its exhibit
function KoalaConfig.CalculateHappiness(koala, exhibit)
	if not koala then return 0 end

	local foodScore = 0
	local cuddleScore = 0
	local socialScore = 0

	-- 1. Food Level (0-60 points)
	if exhibit then
		local food = exhibit:GetAttribute("FoodLevel") or 0
		local maxFood = exhibit:GetAttribute("MaxFoodLevel") or 100
		local foodRatio = math.clamp(food / (maxFood * 0.5), 0, 1) -- 50%+ food gives full points
		foodScore = foodRatio * 60
	else
		foodScore = 30 -- default fallback if not in exhibit
	end

	-- 2. Cuddle Recency (0-25 points)
	local attrCuddle = koala:GetAttribute("LastCuddleTime") or 0
	local stats = koala:FindFirstChild("KoalaStats")
	local statCuddle = (stats and stats:FindFirstChild("LastCuddleTime") and stats.LastCuddleTime.Value) or 0
	local lastCuddle = math.max(attrCuddle, statCuddle)

	local now = workspace:GetServerTimeNow()
	if lastCuddle > 0 and (now - lastCuddle <= KoalaConfig.CUDDLE_BOOST_DURATION) then
		cuddleScore = 25
	end

	-- 3. Social Friends (0-15 points)
	if exhibit then
		local CollectionService = game:GetService("CollectionService")
		local count = 0
		for _, child in ipairs(exhibit:GetChildren()) do
			if child:IsA("Model") and CollectionService:HasTag(child, "KoalaNPC") then
				count += 1
			end
		end
		if count >= 2 then
			socialScore = 15
		elseif count == 1 then
			socialScore = 8
		end
	else
		socialScore = 8
	end

	local total = math.clamp(math.floor(foodScore + cuddleScore + socialScore), 0, 100)
	return total
end

-- Converts happiness score to revenue multiplier
function KoalaConfig.GetHappinessMultiplier(happinessScore)
	if happinessScore >= 85 then
		return 1.35 -- Ecstatic
	elseif happinessScore >= 50 then
		return 1.00 -- Content
	elseif happinessScore >= 20 then
		return 0.40 -- Grumpy / Hungry
	else
		return 0.00 -- Starving
	end
end

-- ============================================================
-- REVENUE MULTIPLIER & DETAILED CALCULATION
-- ============================================================

function KoalaConfig.GetRevenueMultiplier(koala)
	local stats = koala:FindFirstChild("KoalaStats")
	local stage = (stats and stats:FindFirstChild("Stage") and stats.Stage.Value) or (koala:GetAttribute("Stage") or 4)
	local rarity = (stats and stats:FindFirstChild("Rarity") and stats.Rarity.Value) or (koala:GetAttribute("Rarity") or "Cute")

	local stageMult = KoalaConfig.STAGE_REVENUE_MULTIPLIER[stage] or 1.0
	local rarityMult = KoalaConfig.RARITY_REVENUE_MULTIPLIER[rarity] or 1.0

	return stageMult * rarityMult
end

-- Comprehensive revenue calculator for a single koala
function KoalaConfig.CalculateKoalaRevenue(koala, exhibit, exhibitKoalaCount)
	if not koala then return 0, {} end

	local stats = koala:FindFirstChild("KoalaStats")
	local stage = (stats and stats:FindFirstChild("Stage") and stats.Stage.Value) or (koala:GetAttribute("Stage") or 4)
	local rarity = (stats and stats:FindFirstChild("Rarity") and stats.Rarity.Value) or (koala:GetAttribute("Rarity") or "Cute")

	local baseRate = KoalaConfig.STAGE_BASE_REVENUE[stage] or 10
	local rarityMult = KoalaConfig.RARITY_REVENUE_MULTIPLIER[rarity] or 1.0

	-- Outfit bonus
	local hat = koala:GetAttribute("EquippedOutfit_Hat") or koala:GetAttribute("EquippedOutfit")
	local necklace = koala:GetAttribute("EquippedOutfit_Necklace")

	local hatBonus = 0
	local necklaceBonus = 0
	local outfitConfigSuccess, OutfitShopConfig = pcall(function()
		return require(game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("OutfitShopConfig"))
	end)

	if outfitConfigSuccess and OutfitShopConfig then
		if hat and hat ~= "" then
			hatBonus = OutfitShopConfig.GetOutfitBonus(hat)
		end
		if necklace and necklace ~= "" then
			necklaceBonus = OutfitShopConfig.GetOutfitBonus(necklace)
		end
	end

	local outfitMult = 1.0 + hatBonus + necklaceBonus
	if hat and necklace and hat ~= "" and necklace ~= "" then
		outfitMult += 0.20 -- Dual Outfit Combo Bonus
	end

	-- Happiness
	local happinessScore = KoalaConfig.CalculateHappiness(koala, exhibit)
	local happinessMult = KoalaConfig.GetHappinessMultiplier(happinessScore)

	-- Crowd Bonus
	local crowdMult = 1.0
	local count = exhibitKoalaCount or 1
	if count >= 7 then
		crowdMult = 1.25
	elseif count >= 4 then
		crowdMult = 1.10
	end

	local finalPayout = math.floor(baseRate * rarityMult * outfitMult * happinessMult * crowdMult)

	local breakdown = {
		baseRate = baseRate,
		stage = stage,
		rarity = rarity,
		rarityMult = rarityMult,
		hat = hat,
		hatBonus = hatBonus,
		necklace = necklace,
		necklaceBonus = necklaceBonus,
		outfitMult = outfitMult,
		happinessScore = happinessScore,
		happinessMult = happinessMult,
		crowdMult = crowdMult,
		finalPayout = finalPayout
	}

	return finalPayout, breakdown
end

-- ============================================================
-- MILK BOTTLE PRICING CONFIG
-- ============================================================
KoalaConfig.BASE_MILK_BOTTLE_PRICE = 50
KoalaConfig.PRICE_PER_OWNED_KOALA = 25

function KoalaConfig.GetMilkBottlePrice(ownedKoalasCount)
	ownedKoalasCount = ownedKoalasCount or 0
	return KoalaConfig.BASE_MILK_BOTTLE_PRICE + (ownedKoalasCount * KoalaConfig.PRICE_PER_OWNED_KOALA)
end

return KoalaConfig
