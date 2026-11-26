local StaffConfig = {}

StaffConfig.RoleOrder = { "Feeder", "CuddleBuddy" }

StaffConfig.Roles = {
	Feeder = {
		id = "Feeder",
		title = "Feeder Assistant",
		icon = "🌿",
		modelType = "HumanoidNPC",
		description = "Collects eucalyptus leaves and keeps your exhibit feeders topped up automatically.",
		summaryLine = "Guarantees covered feeders stay stocked automatically.",
		hiredToast = "🌿 Hired Feeder Assistant! Feeders will stay stocked.",
		deskName = "Downstairs Desk 3",

		-- Economy
		hireCost = 1500,
		upkeepCost = 150,       -- Charged every upkeepInterval seconds
		upkeepInterval = 60,    -- 1 minute

		-- Work requirements before hiring
		requirements = {
			minManualRefills = 15,
			requireSecondExhibit = true,
		},

		-- Behavior
		maxExhibits = 2,        -- Max repaired exhibits one Feeder Assistant can cover
		feedInterval = 15,      -- Seconds between guaranteed top-up ticks
		feedAmountFraction = 0.25, -- Restores 25% of MaxFoodLevel per tick
	},

	CuddleBuddy = {
		id = "CuddleBuddy",
		title = "Cuddle Buddy",
		icon = "💖",
		modelType = "HumanoidNPC",
		description = "A friendly keeper who cuddles your koalas to keep their Cuddle Care happiness bonus maxed out.",
		summaryLine = "Keeps covered koalas cuddled for +25 pts happiness & 1.5x growth.",
		hiredToast = "💖 Hired Cuddle Buddy! Koalas will stay cuddled.",
		deskName = "Downstairs Desk 3",

		-- Economy
		hireCost = 2000,
		upkeepCost = 200,
		upkeepInterval = 60,

		-- Work requirements before hiring
		requirements = {
			requireSecondExhibit = true,
		},

		-- Behavior
		maxExhibits = 2,
		cuddleInterval = 15,         -- Seconds between guaranteed cuddle ticks
		cuddleRefreshThreshold = 150, -- Re-cuddle before 180s boost expires
	},
}

function StaffConfig.GetRole(roleId)
	return StaffConfig.Roles[roleId]
end

return StaffConfig
