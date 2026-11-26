-- Tool Shop GUI Controller
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for GUI
local screenGui = script.Parent
local shopFrame = screenGui:FindFirstChild("ShopFrame")
local closeBtn = shopFrame and shopFrame:FindFirstChild("CloseButton")
local toolContainer = shopFrame and shopFrame:FindFirstChild("ToolContainer")

-- Get RemoteEvent
local purchaseEvent = ReplicatedStorage:WaitForChild("PurchaseToolEvent")
local openShopEvent = ReplicatedStorage:WaitForChild("OpenShopEvent")

local GameConstants = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GameConstants"))
local FEED_BAG = GameConstants.FeedBag

-- Track owned tools locally
local ownedTools = {}

local function findTitleLabel(card)
    local names = {"Title", "ToolName", "ItemName", "Name", "Label"}
    for _, name in ipairs(names) do
        local found = card:FindFirstChild(name)
        if found and found:IsA("TextLabel") then
            return found
        end
    end
    for _, child in ipairs(card:GetChildren()) do
        if child:IsA("TextLabel") then
            local text = child.Text:lower()
            if text:find("milk") or text:find("shovel") or text:find("tag") or text:find("rename") then
                return child
            end
        end
    end
    return nil
end

local function findIconLabel(card)
    local names = {"Icon", "ToolIcon", "ItemIcon"}
    for _, name in ipairs(names) do
        local found = card:FindFirstChild(name)
        if found and (found:IsA("TextLabel") or found:IsA("ImageLabel")) then
            return found
        end
    end
    return nil
end

local function findDescLabel(card)
    local names = {"Description", "Desc", "Subtitle", "Info"}
    for _, name in ipairs(names) do
        local found = card:FindFirstChild(name)
        if found and found:IsA("TextLabel") then
            return found
        end
    end
    local title = findTitleLabel(card)
    local icon = findIconLabel(card)
    for _, child in ipairs(card:GetChildren()) do
        if child:IsA("TextLabel") and child ~= title and child ~= icon and child.Name ~= "Price" then
            return child
        end
    end
    return nil
end

local function updateFeedBagCard(card)
	local buyBtn = card:FindFirstChild("BuyButton")
	if not buyBtn then return end

	local maxLeaves = player:GetAttribute("MaxLeaves") or FEED_BAG.BASE_CAPACITY
	local isMaxed = maxLeaves >= FEED_BAG.MAX_CAPACITY
	local upgradeLevel = math.floor((maxLeaves - FEED_BAG.BASE_CAPACITY) / FEED_BAG.UPGRADE_STEP)
	local nextPrice = FEED_BAG.BASE_UPGRADE_PRICE * (upgradeLevel + 1)

	buyBtn:SetAttribute("ToolName", "FeedBagUpgrade")
	if isMaxed then
		buyBtn:SetAttribute("Price", nil)
		buyBtn.Text = "MAXED"
		buyBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
		buyBtn.Active = false
	else
		buyBtn:SetAttribute("Price", nextPrice)
		buyBtn.Text = "BUY"
		buyBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
		buyBtn.Active = true
	end

	local priceLabel = card:FindFirstChild("Price")
	if priceLabel and priceLabel:IsA("TextLabel") then
		priceLabel.Text = isMaxed and "MAX" or ("$" .. nextPrice)
	end

	local iconLabel = findIconLabel(card)
	if iconLabel and iconLabel:IsA("TextLabel") then
		iconLabel.Text = "🎒"
	end

	local titleLabel = findTitleLabel(card)
	if titleLabel then
		titleLabel.Text = "Feed Bag Upgrade"
	end

	local descLabel = findDescLabel(card)
	if descLabel then
		if isMaxed then
			descLabel.Text = string.format("Holds food to feed koalas! Max Capacity: %d", maxLeaves)
		else
			local nextCapacity = math.min(maxLeaves + FEED_BAG.UPGRADE_STEP, FEED_BAG.MAX_CAPACITY)
			descLabel.Text = string.format("Holds food to feed koalas! Capacity: %d -> %d (+%d)", maxLeaves, nextCapacity, FEED_BAG.UPGRADE_STEP)
		end
	end
end

local function updateMilkBottleCard()
	if not toolContainer then return end
	local card = toolContainer:FindFirstChild("MilkBottle") or toolContainer:FindFirstChild("MilkBottleCard")
	if not card then
		for _, child in ipairs(toolContainer:GetChildren()) do
			if child:IsA("Frame") then
				local buyBtn = child:FindFirstChild("BuyButton")
				if buyBtn and (buyBtn:GetAttribute("ToolName") == "MilkBottle" or child.Name:find("Milk")) then
					card = child
					break
				end
			end
		end
	end
	if not card then return end

	local buyBtn = card:FindFirstChild("BuyButton")
	if not buyBtn then return end

	local KoalaConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("KoalaConfig"))
	local ownedCount = player:GetAttribute("OwnedKoalasCount") or 0
	local nextPrice = KoalaConfig.GetMilkBottlePrice(ownedCount)

	buyBtn:SetAttribute("Price", nextPrice)
	buyBtn:SetAttribute("ToolName", "MilkBottle")
	buyBtn.Text = "BUY"
	buyBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
	buyBtn.Active = true

	local priceLabel = card:FindFirstChild("Price")
	if priceLabel and priceLabel:IsA("TextLabel") then
		priceLabel.Text = "$" .. nextPrice
	end
end

local function setupFeedBagUpgrade()
	if not toolContainer then return end
	local card = toolContainer:FindFirstChild("FeedBagUpgrade")
	if not card then
		local templateCard = nil
		for _, child in ipairs(toolContainer:GetChildren()) do
			if child:IsA("Frame") and child.Name ~= "FeedBagUpgrade" then
				templateCard = child
				break
			end
		end
		
		if templateCard then
			card = templateCard:Clone()
			card.Name = "FeedBagUpgrade"
			
			local buyBtn = card:FindFirstChild("BuyButton")
			if buyBtn then
				buyBtn.MouseButton1Click:Connect(function()
					if not buyBtn.Active then return end
					local toolName = buyBtn:GetAttribute("ToolName")
					local price = buyBtn:GetAttribute("Price")
					if toolName and price then
						purchaseEvent:FireServer(toolName, price)
					end
				end)
			end
			card.Parent = toolContainer
		end
	end
	
	if card then
		updateFeedBagCard(card)
	end
end

-- Function to close shop
local function closeShop()
    screenGui.Enabled = false
end

-- Function to open shop
local function openShop()
    setupFeedBagUpgrade()
    updateMilkBottleCard()
    screenGui.Enabled = true
end

-- Function to update button state
local function updateBuyButton(toolName, owned)
    if not toolContainer then return end
    
    for _, card in pairs(toolContainer:GetChildren()) do
        if card:IsA("Frame") then
            local buyBtn = card:FindFirstChild("BuyButton")
            if buyBtn and buyBtn:GetAttribute("ToolName") == toolName then
                if owned then
                    buyBtn.Text = "OWNED"
                    buyBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                    buyBtn.Active = false
                end
            end
        end
    end
end

-- Handle buy button clicks
if toolContainer then
    for _, card in pairs(toolContainer:GetChildren()) do
        if card:IsA("Frame") then
            local buyBtn = card:FindFirstChild("BuyButton")
            if buyBtn then
                buyBtn.MouseButton1Click:Connect(function()
                    local toolName = buyBtn:GetAttribute("ToolName")
                    local price = buyBtn:GetAttribute("Price")
                    
                    if toolName and price then
                        -- Fire purchase request to server
                        purchaseEvent:FireServer(toolName, price)
                    end
                end)
            end
        end
    end
end

-- Handle close button
if closeBtn then
    closeBtn.MouseButton1Click:Connect(closeShop)
end

-- Listen for purchase responses
purchaseEvent.OnClientEvent:Connect(function(success, toolName, message)
    -- Handle status message if provided
    local statusLabel = shopFrame and shopFrame:FindFirstChild("StatusLabel")
    if statusLabel and message then
        statusLabel.Text = message
        statusLabel.Visible = true
        statusLabel.TextColor3 = success and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
        
        task.delay(3, function()
            if statusLabel.Text == message then
                statusLabel.Visible = false
            end
        end)
    end

    if success then
        -- Update button to show owned (skip for consumables & upgrades)
        if toolName ~= "RenameTag" and toolName ~= "MilkBottle" and toolName ~= "FeedBagUpgrade" then
            updateBuyButton(toolName, true)
            ownedTools[toolName] = true
        elseif toolName == "FeedBagUpgrade" then
            setupFeedBagUpgrade()
        end
    end
end)

-- openShopEvent listener handles opening shop from server
openShopEvent.OnClientEvent:Connect(openShop)

-- Initial setup
setupFeedBagUpgrade()
updateMilkBottleCard()

player:GetAttributeChangedSignal("OwnedKoalasCount"):Connect(updateMilkBottleCard)
