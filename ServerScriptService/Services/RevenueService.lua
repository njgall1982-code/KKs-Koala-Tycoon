local RevenueService = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConstants = require(ReplicatedStorage.Modules.GameConstants)
-- local KoalaCoreManager = require(game:GetService("ServerScriptService").Services.KoalaCoreManager) -- Removed for Decoupling
function RevenueService.Initialize()
	task.spawn(function()
		while true do
			task.wait(GameConstants.Revenue.INTERVAL)
			for _, player in ipairs(Players:GetPlayers()) do
				RevenueService.ProcessPlayerRevenue(player)
			end
		end
	end)
	print("[RevenueService] Initialized.")
end
function RevenueService.ProcessPlayerRevenue(player)
	local leaderstats = player:FindFirstChild("leaderstats")
	local hasExhibit = player:FindFirstChild("HasExhibit")
	if not leaderstats then return end
	local totalRevenue = 0
	local koalaCount = 0
	-- Get all exhibits and their status
	local exhibitList = {
		workspace:FindFirstChild("TutorialExhibit_Workspace"),
		workspace:FindFirstChild("SecondExhibit_Workspace"),
	}

	local allKoalas = game:GetService("CollectionService"):GetTagged("KoalaNPC")
	
	for _, koala in ipairs(allKoalas) do
		local targetExhibit = nil
		
		-- 1. Check if explicitly in an exhibit folder
		for _, ex in ipairs(exhibitList) do
			if ex and koala:IsDescendantOf(ex) then
				targetExhibit = ex
				break
			end
		end
		
		-- 2. Fallback: Check proximity (for DevKoalas spawned in Workspace)
		if not targetExhibit and koala.Parent == workspace then
			local minDist = 50
			for _, ex in ipairs(exhibitList) do
				if ex and ex:FindFirstChild("Ground") then
					local dist = (koala:GetPivot().Position - ex.Ground.Position).Magnitude
					if dist < minDist then
						minDist = dist
						targetExhibit = ex
					end
				end
			end
		end

		-- If we found an exhibit, check food and add revenue
		if targetExhibit then
			local foodLevel = targetExhibit:GetAttribute("FoodLevel") or 0
			if foodLevel > 0 then
				local stageMult = koala:GetAttribute("RevenueMultiplier") or 1.0
				if stageMult > 0 then
					koalaCount += 1
					totalRevenue += GameConstants.Revenue.PER_KOALA * stageMult
					if hasExhibit then hasExhibit.Value = true end
				end
			else
				-- Optional: notify player that this specific koala is hungry?
			end
		end
	end
	-- Debug: Log what we found
	if koalaCount > 0 then
		print("[RevenueService] Found " .. koalaCount .. " koala(s) across exhibits for " .. player.Name .. ", paying $" .. totalRevenue)
	end
	-- Only pay if they actually earned something
	if totalRevenue > 0 then
		local signals = game:GetService("ServerStorage"):FindFirstChild("Signals")
		local grantCurrency = signals and signals:FindFirstChild("GrantCurrency")
		if grantCurrency then
			grantCurrency:Fire(player, totalRevenue, "Cash")
		else
			-- Fallback if signals system is missing
			leaderstats.Cash.Value += totalRevenue
		end
	end
end
return RevenueService
