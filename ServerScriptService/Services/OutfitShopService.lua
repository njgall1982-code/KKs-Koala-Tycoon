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

local connections = {}

local function connectPrompt(prompt)
	if not prompt:IsA("ProximityPrompt") then return end
	if prompt.Name ~= "OutfitShopPrompt" and not prompt.ObjectText:lower():find("outfit") then return end
	if connections[prompt] then return end

	print("[OutfitShopService] Connected to Outfit Shop prompt at: " .. prompt:GetFullName())
	connections[prompt] = prompt.Triggered:Connect(function(player)
		openOutfitShopEvent:FireClient(player)
	end)

	prompt.Destroying:Connect(function()
		if connections[prompt] then
			connections[prompt]:Disconnect()
			connections[prompt] = nil
		end
	end)
end

local function isVendorModel(model)
	if not model:IsA("Model") then return false end
	local name = model.Name:lower()
	return name:find("outfit") or name:find("outift") or name == "koala vendor"
end

local function attachPromptToVendor(vendor)
	local humanoid = vendor:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayName = "Outfit Shop"
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end

	local targetPart = vendor:FindFirstChild("HumanoidRootPart") or vendor:FindFirstChild("Torso") or vendor.PrimaryPart or vendor:FindFirstChildWhichIsA("BasePart") or vendor
	if not targetPart then return end

	local prompt = targetPart:FindFirstChild("OutfitShopPrompt") or vendor:FindFirstChild("OutfitShopPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "OutfitShopPrompt"
		prompt.ActionText = "Browse Outfits"
		prompt.ObjectText = "Outfit Shop"
		prompt.HoldDuration = 0
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 10
		prompt.Parent = targetPart
		print("[OutfitShopService] Created OutfitShopPrompt on " .. targetPart:GetFullName())
	end

	connectPrompt(prompt)
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

	-- Scan existing descendants for prompts and vendor models
	for _, desc in ipairs(workspace:GetDescendants()) do
		if desc:IsA("ProximityPrompt") then
			connectPrompt(desc)
		elseif isVendorModel(desc) then
			attachPromptToVendor(desc)
		end
	end

	-- Listen for dynamically added models or prompts
	workspace.DescendantAdded:Connect(function(desc)
		if desc:IsA("ProximityPrompt") then
			connectPrompt(desc)
		elseif isVendorModel(desc) then
			attachPromptToVendor(desc)
		end
	end)

	print("[OutfitShopService] Initialized (Dynamic Vendor Detection Mode).")
end

return OutfitShopService
