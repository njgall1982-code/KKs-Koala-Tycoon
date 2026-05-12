-- EconomyService.lua
local EconomyService = {}

local ServerStorage = game:GetService("ServerStorage")
local Signals = ServerStorage:WaitForChild("Signals")
local GrantCurrency = Signals:WaitForChild("GrantCurrency")

function EconomyService.Initialize()
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
