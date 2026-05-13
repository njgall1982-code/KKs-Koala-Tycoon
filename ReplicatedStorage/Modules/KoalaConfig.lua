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
KoalaConfig.CUDDLE_BOOST_DURATION  = 30
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

KoalaConfig.STAGE_REVENUE_MULTIPLIER = { 1.25, 1.0, 1.0, 1.0 }
KoalaConfig.RARITY_REVENUE_MULTIPLIER = {
	["Cute"] = 1.0,
	["Extra Cute"] = 2.0,
	["Ultra Cute"] = 4.0
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

function KoalaConfig.GetRevenueMultiplier(koala)
	local stats = koala:FindFirstChild("KoalaStats")
	if not stats then return 1.0 end

	local stageVal = stats:FindFirstChild("Stage")
	local rarityVal = stats:FindFirstChild("Rarity")

	local stage = stageVal and stageVal.Value or 4
	local rarity = rarityVal and rarityVal.Value or "Cute"

	local stageMult = KoalaConfig.STAGE_REVENUE_MULTIPLIER[stage] or 1.0
	local rarityMult = KoalaConfig.RARITY_REVENUE_MULTIPLIER[rarity] or 1.0

	return stageMult * rarityMult
end

return KoalaConfig
