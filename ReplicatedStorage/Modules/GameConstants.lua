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
		PER_KOALA = 25 -- $25 per koala in exhibit (simplified)
	}
}

return GameConstants
