-- OutfitShopService.lua
-- Server-side service for managing outfit purchases and physical shop interactions.
local OutfitShopService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

-- Ensure RemoteEvents exist
local purchaseOutfitEvent = ReplicatedStorage:FindFirstChild("PurchaseOutfitEvent")
if not purchaseOutfitEvent then
	purchaseOutfitEvent = Instance.new("RemoteEvent")
	purchaseOutfitEvent.Name = "PurchaseOutfitEvent"
	purchaseOutfitEvent.Parent = ReplicatedStorage
end

local openOutfitShopEvent = ReplicatedStorage:FindFirstChild("OpenOutfitShopEvent")
if not openOutfitShopEvent then
	openOutfitShopEvent = Instance.new("RemoteEvent")
	openOutfitShopEvent.Name = "OpenOutfitShopEvent"
	openOutfitShopEvent.Parent = ReplicatedStorage
end

local signals = ServerStorage:WaitForChild("Signals")
local transactionRequest = signals:WaitForChild("TransactionRequest")

local OutfitShopConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("OutfitShopConfig"))
local KoalaOutfitService = require(game:GetService("ServerScriptService"):WaitForChild("Services"):WaitForChild("KoalaOutfitService"))

local function setupVendorPrompt()
	local shop = workspace:FindFirstChild("Shop")
	local vendor = shop and shop:FindFirstChild("Koala Vendor")
	local hrp = vendor and vendor:FindFirstChild("HumanoidRootPart")
	if hrp then
		local prompt = hrp:FindFirstChild("OutfitShopPrompt")
		if not prompt then
			prompt = Instance.new("ProximityPrompt")
			prompt.Name = "OutfitShopPrompt"
			prompt.ActionText = "Browse Outfits"
			prompt.ObjectText = "Outfit Shop"
			prompt.HoldDuration = 0
			prompt.RequiresLineOfSight = false
			prompt.MaxActivationDistance = 10
			prompt.Parent = hrp
		end
		
		-- Clear existing connections if any
		prompt.Triggered:Connect(function(player)
			openOutfitShopEvent:FireClient(player)
		end)
		print("[OutfitShopService] Configured Outfit Shop ProximityPrompt on Koala Vendor.")
	else
		warn("[OutfitShopService] Koala Vendor HumanoidRootPart not found. Cannot set up ProximityPrompt.")
	end
end

function OutfitShopService.Initialize()
	-- Guard Clause
	if OutfitShopService._initialized then return end
	OutfitShopService._initialized = true

	-- Purchase Handler
	purchaseOutfitEvent.OnServerEvent:Connect(function(player, outfitName, price)
		if not player or not outfitName or not price then return end

		local config = OutfitShopConfig.GetOutfit(outfitName)
		if not config or price ~= config.Price then
			warn(string.format("[OutfitShopService] Rejected purchase request from %s for outfit '%s' with price %s (expected %s)", 
				player.Name, tostring(outfitName), tostring(price), config and tostring(config.Price) or "nil"))
			return
		end

		-- Decoupled Transaction Request
		local success, reason = transactionRequest:Invoke(player, config.Price, "BuyOutfit_" .. outfitName)
		if success then
			-- Grant the outfit via KoalaOutfitService
			KoalaOutfitService.UnlockOutfit(player, outfitName)
			purchaseOutfitEvent:FireClient(player, true, outfitName, "Purchase successful!")
		else
			purchaseOutfitEvent:FireClient(player, false, outfitName, reason or "Insufficient funds!")
		end
	end)

	-- Setup Physical Prompt
	task.spawn(function()
		local shop = workspace:WaitForChild("Shop", 10)
		local vendor = shop and shop:WaitForChild("Koala Vendor", 10)
		if vendor then
			setupVendorPrompt()
		else
			-- Fallback: listen for descendent
			local conn
			conn = workspace.DescendantAdded:Connect(function(desc)
				if desc.Name == "Koala Vendor" and desc:IsA("Model") then
					setupVendorPrompt()
					conn:Disconnect()
				end
			end)
		end
	end)

	print("[OutfitShopService] Initialized.")
end

return OutfitShopService
