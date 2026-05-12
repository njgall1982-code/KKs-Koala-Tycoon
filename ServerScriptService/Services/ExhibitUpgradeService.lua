local ExhibitUpgradeService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Signals = ServerStorage:WaitForChild("Signals")

-- Config
local UPGRADES = {
	Feeder = {
		[1] = { Cost = 500, MaxFood = 200, Label = "Large Feeder" },
		[2] = { Cost = 2000, MaxFood = 400, Label = "Bulk Feeder" },
		[3] = { Cost = 10000, MaxFood = 1000, Label = "Auto-Silo" },
	},
	Exhibit = {
		[1] = { Cost = 1000, MaxKoalas = 20, Label = "Double Space" },
		[2] = { Cost = 5000, MaxKoalas = 30, Label = "Triple Space" },
		[3] = { Cost = 20000, MaxKoalas = 50, Label = "Koala Sanctuary" },
	}
}

function ExhibitUpgradeService.Initialize()
	-- Create RemoteEvent if it doesn't exist
	local upgradeEvent = ReplicatedStorage:FindFirstChild("UpgradeExhibit")
	if not upgradeEvent then
		upgradeEvent = Instance.new("RemoteEvent")
		upgradeEvent.Name = "UpgradeExhibit"
		upgradeEvent.Parent = ReplicatedStorage
	end

	upgradeEvent.OnServerEvent:Connect(function(player, exhibitPath, upgradeType)
		-- Find exhibit
		local pathParts = string.split(exhibitPath, ".")
		local target = game
		for _, part in ipairs(pathParts) do
			target = target:FindFirstChild(part)
			if not target then break end
		end

		if not target or not target:IsA("Folder") or not target.Name:find("_Workspace") then
			return
		end

		local currentLevel = target:GetAttribute(upgradeType .. "Level") or 1
		local nextTier = UPGRADES[upgradeType][currentLevel]
		
		if not nextTier then 
			print("[ExhibitUpgradeService] Already at max level for " .. upgradeType)
			return 
		end

		-- Request payment
		local transactionRequest = Signals:FindFirstChild("TransactionRequest")
		if transactionRequest then
			local success, err = transactionRequest:Invoke(player, nextTier.Cost, target.Name .. " Upgrade")
			if success then
				-- Apply upgrade
				target:SetAttribute(upgradeType .. "Level", currentLevel + 1)
				if upgradeType == "Feeder" then
					target:SetAttribute("MaxFoodLevel", nextTier.MaxFood)
				elseif upgradeType == "Exhibit" then
					target:SetAttribute("MaxKoalas", nextTier.MaxKoalas)
				end
				print("[ExhibitUpgradeService] " .. player.Name .. " upgraded " .. upgradeType .. " for " .. target.Name)
				
				-- Fire UpdateQuest to notify success
				local updateQuest = Signals:FindFirstChild("UpdateQuest")
				if updateQuest then
					updateQuest:Fire(player, "✅ Exhibit Upgraded!")
					task.delay(3, function() updateQuest:Fire(player, "") end)
				end
			else
				warn("[ExhibitUpgradeService] Payment failed: " .. tostring(err))
			end
		end
	end)

	print("[ExhibitUpgradeService] Initialized.")
end

return ExhibitUpgradeService
