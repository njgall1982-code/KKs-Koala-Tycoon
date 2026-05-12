-- EconomyService.lua
local EconomyService = {}

local ServerStorage = game:GetService("ServerStorage")
local Signals = ServerStorage:WaitForChild("Signals")
local GrantCurrency = Signals:WaitForChild("GrantCurrency")

function EconomyService.Initialize()
	-- Spending Logic (BindableFunction)
	Signals:WaitForChild("TransactionRequest").OnInvoke = function(player, amount, reason)
		if not player or not player:FindFirstChild("leaderstats") then 
			return false, "No data" 
		end
		
		local cash = player.leaderstats:FindFirstChild("Cash")
		if cash and cash.Value >= amount then
			cash.Value -= amount
			print(string.format("[EconomyService] Processed %s for %s: -$%d", reason, player.Name, amount))
			
			-- Visual feedback
			local showStatus = Signals:FindFirstChild("ShowStatus")
			if showStatus then
				showStatus:Fire(player, "-$" .. amount .. " " .. reason, Color3.fromRGB(255, 50, 50))
			end
			
			return true
		end
		return false, "Insufficient funds"
	end

	-- Granting Logic (BindableEvent)
	GrantCurrency.Event:Connect(function(player, amount, currencyType)
		currencyType = currencyType or "Cash"
		
		local leaderstats = player:FindFirstChild("leaderstats")
		if not leaderstats then return end
		
		local currency = leaderstats:FindFirstChild(currencyType)
		if currency and currency:IsA("IntValue") then
			currency.Value += amount
			print(string.format("[EconomyService] %s +%d for %s", currencyType, amount, player.Name))
			
			-- Fire ShowStatus for visual feedback
			local showStatus = Signals:FindFirstChild("ShowStatus")
			if showStatus then
				showStatus:Fire(player, "+" .. amount .. " " .. currencyType, Color3.fromRGB(0, 255, 0))
			end
		end
	end)
	
	print("[EconomyService] Initialized.")
end

return EconomyService
