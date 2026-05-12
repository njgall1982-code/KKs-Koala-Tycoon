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
	local totalKoalas = 0
	local CollectionService = game:GetService("CollectionService")

	-- Scan all exhibits in workspace
	for _, exhibit in ipairs(workspace:GetChildren()) do
		if not exhibit.Name:find("Exhibit_Workspace") then continue end
		
		local foodLevel = exhibit:GetAttribute("FoodLevel") or 0
		if foodLevel <= 0 then continue end
		
		for _, koala in ipairs(exhibit:GetChildren()) do
			if CollectionService:HasTag(koala, "KoalaNPC") then
				local stageMult = koala:GetAttribute("RevenueMultiplier") or 1.0
				totalKoalas += 1
				totalRevenue += GameConstants.Revenue.PER_KOALA * stageMult
				if hasExhibit then hasExhibit.Value = true end
			end
		end
	end

	-- Debug: Log what we found
	if totalKoalas > 0 then
		print("[RevenueService] Found " .. totalKoalas .. " koala(s) in " .. player.Name .. "'s exhibits, paying $" .. totalRevenue)
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
