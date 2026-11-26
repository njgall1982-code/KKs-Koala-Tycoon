local RevenueService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local GameConstants = require(ReplicatedStorage.Modules.GameConstants)
local KoalaConfig = require(ReplicatedStorage.Modules.KoalaConfig)

-- Remote objects for UI & Terminal
local getAnalyticsDataRemote
local terminalActionRemote

function RevenueService.Initialize()
	-- Ensure remotes exist in ReplicatedStorage
	getAnalyticsDataRemote = ReplicatedStorage:FindFirstChild("GetZooAnalyticsData")
	if not getAnalyticsDataRemote then
		getAnalyticsDataRemote = Instance.new("RemoteFunction")
		getAnalyticsDataRemote.Name = "GetZooAnalyticsData"
		getAnalyticsDataRemote.Parent = ReplicatedStorage
	end

	terminalActionRemote = ReplicatedStorage:FindFirstChild("ZooTerminalAction")
	if not terminalActionRemote then
		terminalActionRemote = Instance.new("RemoteFunction")
		terminalActionRemote.Name = "ZooTerminalAction"
		terminalActionRemote.Parent = ReplicatedStorage
	end

	-- Connect client requests
	getAnalyticsDataRemote.OnServerInvoke = function(player)
		return RevenueService.GetAnalyticsPayload(player)
	end

	terminalActionRemote.OnServerInvoke = function(player, action, data)
		return RevenueService.HandleTerminalAction(player, action, data)
	end

	-- Background revenue loop
	task.spawn(function()
		while true do
			task.wait(GameConstants.Revenue.INTERVAL)

			for _, player in ipairs(Players:GetPlayers()) do
				RevenueService.ProcessPlayerRevenue(player)
			end
		end
	end)

	print("[RevenueService] Initialized with Happiness, Rarity & Outfit scaling.")
end

-- Decodes unlocked telemetry list helper
local function getUnlockedTelemetryTable(player)
	local attr = player:GetAttribute("UnlockedTelemetry")
	if not attr or attr == "" then return {} end
	local list = {}
	pcall(function()
		list = HttpService:JSONDecode(attr)
	end)
	return list or {}
end

local function isExhibitTelemetryUnlocked(player, exhibitName)
	local list = getUnlockedTelemetryTable(player)
	return list[exhibitName] == true or table.find(list, exhibitName) ~= nil
end

local function getUnlockedDiagnosticsTable(player)
	local attr = player:GetAttribute("UnlockedDiagnostics")
	if not attr or attr == "" then return {} end
	local list = {}
	pcall(function()
		list = HttpService:JSONDecode(attr)
	end)
	return list or {}
end

local function isExhibitDiagnosticsUnlocked(player, exhibitName)
	local list = getUnlockedDiagnosticsTable(player)
	return list[exhibitName] == true or table.find(list, exhibitName) ~= nil
end

function RevenueService.ProcessPlayerRevenue(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local hasExhibit = player:FindFirstChild("HasExhibit")
	if not leaderstats then return end

	local totalRevenue = 0
	local totalKoalas = 0

	for _, exhibit in ipairs(workspace:GetChildren()) do
		if not (exhibit:IsA("Folder") and exhibit.Name:find("_Workspace")) then continue end

		-- Count koalas first for crowd bonus
		local koalaList = {}
		for _, child in ipairs(exhibit:GetChildren()) do
			if child:IsA("Model") and CollectionService:HasTag(child, "KoalaNPC") then
				table.insert(koalaList, child)
			end
		end

		local exhibitKoalaCount = #koalaList
		local exhibitRevenue = 0
		local totalHappinessSum = 0

		for _, koala in ipairs(koalaList) do
			local payout, breakdown = KoalaConfig.CalculateKoalaRevenue(koala, exhibit, exhibitKoalaCount)

			-- Set attributes for real-time inspection & UI display
			koala:SetAttribute("Happiness", breakdown.happinessScore)
			koala:SetAttribute("CurrentRevenue", payout)
			koala:SetAttribute("RevenueMultiplier", breakdown.rarityMult * breakdown.outfitMult * breakdown.happinessMult * breakdown.crowdMult)

			totalHappinessSum += breakdown.happinessScore
			exhibitRevenue += payout
			totalKoalas += 1
		end

		local exhibitAvgHappiness = (exhibitKoalaCount > 0) and math.floor(totalHappinessSum / exhibitKoalaCount) or 100
		exhibit:SetAttribute("LiveRevenue", exhibitRevenue)
		exhibit:SetAttribute("AverageHappiness", exhibitAvgHappiness)

		totalRevenue += exhibitRevenue
		if exhibitKoalaCount > 0 and hasExhibit then
			hasExhibit.Value = true
		end
	end

	-- Store player's live total revenue rate attribute for quick UI reads
	player:SetAttribute("LiveRevenueRate", totalRevenue)
	player:SetAttribute("TotalKoalas", totalKoalas)

	-- Pay player
	if totalRevenue > 0 then
		local signals = ServerStorage:FindFirstChild("Signals")
		local grantCurrency = signals and signals:FindFirstChild("GrantCurrency")
		if grantCurrency then
			grantCurrency:Fire(player, totalRevenue, "Cash")
		else
			leaderstats.Cash.Value += totalRevenue
		end
	end
end

-- Builds full analytics payload for the client dashboard
function RevenueService.GetAnalyticsPayload(player)
	local isTerminalUnlocked = player:GetAttribute("ZooComputerUnlocked") == true
	local unlockedTelemetry = getUnlockedTelemetryTable(player)

	local exhibitsData = {}
	local parkTotalRevenue = 0
	local parkTotalKoalas = 0
	local parkTotalHappinessSum = 0

	for _, exhibit in ipairs(workspace:GetChildren()) do
		if not (exhibit:IsA("Folder") and exhibit.Name:find("_Workspace")) then continue end

		local exhibitName = exhibit.Name
		local displayName = exhibit:GetAttribute("DisplayName") or exhibitName:gsub("_Workspace", "")
		local foodLevel = exhibit:GetAttribute("FoodLevel") or 0
		local maxFoodLevel = exhibit:GetAttribute("MaxFoodLevel") or 100
		local maxKoalas = exhibit:GetAttribute("MaxKoalas") or 10
		local isRepaired = exhibit:GetAttribute("IsRepaired") == true

		local koalasInExhibit = {}
		for _, child in ipairs(exhibit:GetChildren()) do
			if child:IsA("Model") and CollectionService:HasTag(child, "KoalaNPC") then
				table.insert(koalasInExhibit, child)
			end
		end

		local koalaCount = #koalasInExhibit
		local exhibitRevenue = 0
		local exhibitHappinessSum = 0
		local koalaCards = {}

		local isTeleUnlocked = isExhibitTelemetryUnlocked(player, exhibitName)
		local isDiagUnlocked = isExhibitDiagnosticsUnlocked(player, exhibitName)
		local cuddledCount = 0

		for _, koala in ipairs(koalasInExhibit) do
			local payout, breakdown = KoalaConfig.CalculateKoalaRevenue(koala, exhibit, koalaCount)
			exhibitRevenue += payout
			exhibitHappinessSum += breakdown.happinessScore

			local attrCuddle = koala:GetAttribute("LastCuddleTime") or 0
			local stats = koala:FindFirstChild("KoalaStats")
			local statCuddle = (stats and stats:FindFirstChild("LastCuddleTime") and stats.LastCuddleTime.Value) or 0
			local lastCuddle = math.max(attrCuddle, statCuddle)

			local now = workspace:GetServerTimeNow()
			local isCuddled = (lastCuddle > 0) and (now - lastCuddle <= KoalaConfig.CUDDLE_BOOST_DURATION)
			if isCuddled then
				cuddledCount += 1
			end

			if isTeleUnlocked then
				local stage = (stats and stats:FindFirstChild("Stage") and stats.Stage.Value) or (koala:GetAttribute("Stage") or 4)
				local stageName = koala:GetAttribute("StageName") or (stage == 4 and "Adult" or (stage == 3 and "2 Year" or (stage == 2 and "1 Year" or "Newborn")))
				local rarity = (stats and stats:FindFirstChild("Rarity") and stats.Rarity.Value) or (koala:GetAttribute("Rarity") or "Cute")
				local displayNameKoala = koala:GetAttribute("DisplayName") or koala.Name

				local hat = koala:GetAttribute("EquippedOutfit_Hat") or koala:GetAttribute("EquippedOutfit") or ""
				local necklace = koala:GetAttribute("EquippedOutfit_Necklace") or ""

				table.insert(koalaCards, {
					id = koala:GetFullName(),
					name = displayNameKoala,
					stage = stage,
					stageName = stageName,
					rarity = rarity,
					hat = hat,
					necklace = necklace,
					happiness = breakdown.happinessScore,
					payout = payout,
					breakdown = breakdown,
					isCuddled = isCuddled
				})
			end
		end

		local avgHappiness = (koalaCount > 0) and math.floor(exhibitHappinessSum / koalaCount) or 100

		local foodRatio = math.clamp(foodLevel / (math.max(maxFoodLevel, 1) * 0.5), 0, 1)
		local foodScore = math.floor(foodRatio * 60)
		local cuddleScore = (koalaCount > 0) and math.round((cuddledCount / koalaCount) * 25) or 0
		local socialScore = (koalaCount >= 2) and 15 or ((koalaCount == 1) and 8 or 0)
		local wasteCount = exhibit:GetAttribute("WasteCount") or 0
		local cleanlinessPenalty = KoalaConfig.CalculateCleanlinessPenalty(wasteCount)

		parkTotalRevenue += exhibitRevenue
		parkTotalKoalas += koalaCount
		parkTotalHappinessSum += exhibitHappinessSum

		table.insert(exhibitsData, {
			name = exhibitName,
			displayName = displayName,
			exhibitPath = exhibit:GetFullName(),
			foodLevel = foodLevel,
			maxFoodLevel = maxFoodLevel,
			koalaCount = koalaCount,
			maxKoalas = maxKoalas,
			isRepaired = isRepaired,
			wasteCount = wasteCount,
			revenue = exhibitRevenue,
			averageHappiness = avgHappiness,
			isTelemetryUnlocked = isTeleUnlocked,
			isDiagnosticsUnlocked = isDiagUnlocked,
			happinessBreakdown = {
				foodScore = foodScore,
				foodMax = 60,
				cuddleScore = cuddleScore,
				cuddleMax = 25,
				cuddledCount = cuddledCount,
				koalaCount = koalaCount,
				socialScore = socialScore,
				socialMax = 15,
				wasteCount = wasteCount,
				wasteGrace = KoalaConfig.WASTE_GRACE_COUNT,
				cleanlinessPenalty = cleanlinessPenalty,
				totalHappiness = avgHappiness,
			},
			koalas = koalaCards
		})
	end

	local parkAverageHappiness = (parkTotalKoalas > 0) and math.floor(parkTotalHappinessSum / parkTotalKoalas) or 100

	return {
		isTerminalUnlocked = isTerminalUnlocked,
		totalRevenueRate = parkTotalRevenue,
		totalRevenuePerMin = parkTotalRevenue * (60 / GameConstants.Revenue.INTERVAL),
		totalKoalas = parkTotalKoalas,
		averageHappiness = parkAverageHappiness,
		terminalCost = GameConstants.Revenue.TERMINAL_UNLOCK_COST or 350,
		telemetryCost = GameConstants.Revenue.TELEMETRY_UNLOCK_COST or 250,
		diagnosticsCost = GameConstants.Revenue.DIAGNOSTICS_UNLOCK_COST or 200,
		exhibits = exhibitsData
	}
end

-- Handles terminal unlock purchases and exhibit telemetry/diagnostics unlocks
function RevenueService.HandleTerminalAction(player, action, data)
	local signals = ServerStorage:FindFirstChild("Signals")
	local transactionRequest = signals and signals:FindFirstChild("TransactionRequest")
	if not transactionRequest then
		return false, "Economy service signal missing"
	end

	if action == "UnlockTerminal" then
		if player:GetAttribute("ZooComputerUnlocked") == true then
			return true, "Already unlocked"
		end

		local cost = GameConstants.Revenue.TERMINAL_UNLOCK_COST or 350
		local success, err = transactionRequest:Invoke(player, cost, "Zoo Analytics Terminal")
		if success then
			player:SetAttribute("ZooComputerUnlocked", true)
			print(string.format("[RevenueService] %s unlocked Zoo Analytics Terminal for $%d", player.Name, cost))
			return true, RevenueService.GetAnalyticsPayload(player)
		else
			return false, err or "Insufficient funds"
		end

	elseif action == "UnlockExhibitTelemetry" then
		local exhibitName = data
		if not exhibitName or exhibitName == "" then
			return false, "Invalid exhibit"
		end

		if isExhibitTelemetryUnlocked(player, exhibitName) then
			return true, "Already unlocked"
		end

		local cost = GameConstants.Revenue.TELEMETRY_UNLOCK_COST or 250
		local success, err = transactionRequest:Invoke(player, cost, "Telemetry Module (" .. exhibitName .. ")")
		if success then
			local list = getUnlockedTelemetryTable(player)
			list[exhibitName] = true
			player:SetAttribute("UnlockedTelemetry", HttpService:JSONEncode(list))
			print(string.format("[RevenueService] %s unlocked telemetry for %s for $%d", player.Name, exhibitName, cost))
			return true, RevenueService.GetAnalyticsPayload(player)
		else
			return false, err or "Insufficient funds"
		end

	elseif action == "UnlockExhibitDiagnostics" then
		local exhibitName = data
		if not exhibitName or exhibitName == "" then
			return false, "Invalid exhibit"
		end

		if isExhibitDiagnosticsUnlocked(player, exhibitName) then
			return true, "Already unlocked"
		end

		local cost = GameConstants.Revenue.DIAGNOSTICS_UNLOCK_COST or 200
		local success, err = transactionRequest:Invoke(player, cost, "Diagnostics Module (" .. exhibitName .. ")")
		if success then
			local list = getUnlockedDiagnosticsTable(player)
			list[exhibitName] = true
			player:SetAttribute("UnlockedDiagnostics", HttpService:JSONEncode(list))
			print(string.format("[RevenueService] %s unlocked diagnostics for %s for $%d", player.Name, exhibitName, cost))
			return true, RevenueService.GetAnalyticsPayload(player)
		else
			return false, err or "Insufficient funds"
		end
	end

	return false, "Unknown action"
end

return RevenueService
