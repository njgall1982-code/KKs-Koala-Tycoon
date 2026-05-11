local RevenueService = {}
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConstants = require(ReplicatedStorage.Modules.GameConstants)
local KoalaCoreManager = require(game:GetService("ServerScriptService").Services.KoalaCoreManager)
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
	-- List of all exhibits to check
	local exhibits = {
		workspace:FindFirstChild("TutorialExhibit_Workspace"),
		workspace:FindFirstChild("SecondExhibit_Workspace"),
	}
	-- Count koalas in ALL exhibits
	for _, exhibit in ipairs(exhibits) do
		if exhibit then
			local foodLevel = exhibit:GetAttribute("FoodLevel") or 0
			if foodLevel > 0 then
				for _, child in ipairs(exhibit:GetChildren()) do
					if child:IsA("Model") and (child.Name:find("Koala") or child.Name:find("KK")) then
						local stageMult = KoalaCoreManager.GetRevenueMultiplier(child)
						if stageMult > 0 then
							koalaCount += 1
							totalRevenue += GameConstants.Revenue.PER_KOALA * stageMult
							if hasExhibit then hasExhibit.Value = true end
						end
					end
				end
			else
				print("[RevenueService] Skipping revenue for " .. exhibit.Name .. " (Hungry Koalas!)")
			end
		end
	end
	-- Debug: Log what we found
	if koalaCount > 0 then
		print("[RevenueService] Found " .. koalaCount .. " koala(s) across exhibits for " .. player.Name .. ", paying $" .. totalRevenue)
	end
	-- Only pay if they actually earned something
	if totalRevenue > 0 then
		leaderstats.Cash.Value += totalRevenue
	end
end
return RevenueService
