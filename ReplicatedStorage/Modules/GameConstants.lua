local GameConstants = {
	Stages = {
		START = "TalkToVet",
		REPAIR = "RepairExhibit",
		COLLECT = "CollectLeaves",
		FEED = "FeedKK",
		UNLOCK = "GetCageKey",
		RESCUE = "RescueKK",
		HOME = "TakeKKHome",
		COMPLETE = "TutorialComplete"
	},
	
	KoalaColors = {
		Color3.fromRGB(150, 150, 150), -- Grey
		Color3.fromRGB(120, 100, 80),  -- Brown
		Color3.fromRGB(50, 50, 50),    -- Black
		Color3.fromRGB(240, 240, 240)  -- White
	},
	
	Revenue = {
		INTERVAL = 5, -- Pay every 5 seconds
		PER_KOALA = 25, -- Legacy fallback
		BASE_RATES = {
			[1] = 10, -- Newborn
			[2] = 18, -- 1 Year
			[3] = 28, -- 2 Year
			[4] = 42, -- Adult
		},
		CROWD_BONUS = {
			{ min = 7, mult = 1.25 },
			{ min = 4, mult = 1.10 },
			{ min = 1, mult = 1.00 }
		},
		OUTFIT_COMBO_BONUS = 0.20, -- Additional +20% if both Hat and Necklace equipped
		TERMINAL_UNLOCK_COST = 350,
		TELEMETRY_UNLOCK_COST = 250,
		DIAGNOSTICS_UNLOCK_COST = 200,
	}
}

return GameConstants
