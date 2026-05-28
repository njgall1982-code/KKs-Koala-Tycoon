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

local function findDescLabel(card)
    local title = findTitleLabel(card)
    for _, child in ipairs(card:GetChildren()) do
        if child:IsA("TextLabel") and child ~= title then
            return child
        end
    end
    return nil
end

local function updateFeedBagCard(card)
	local buyBtn = card:FindFirstChild("BuyButton")
	if not buyBtn then return end

	local maxLeaves = player:GetAttribute("MaxLeaves") or 5
	local upgradeLevel = (maxLeaves - 5) / 5
	local nextPrice = 250 * (upgradeLevel + 1)

	buyBtn:SetAttribute("Price", nextPrice)
	buyBtn:SetAttribute("ToolName", "FeedBagUpgrade")
	
	local originalText = buyBtn.Text
	if originalText:find("Buy") or originalText:find("%$") then
		if originalText:find("Buy") then
			buyBtn.Text = "Buy ($" .. nextPrice .. ")"
		else
			buyBtn.Text = "$" .. nextPrice
		end
	else
		buyBtn.Text = "$" .. nextPrice
	end

	local titleLabel = findTitleLabel(card)
	if titleLabel then
		titleLabel.Text = "Feed Bag Upgrade"
	end

	local descLabel = findDescLabel(card)
	if descLabel then
		descLabel.Text = string.format("Holds %d leaves (+5)", maxLeaves + 5)
	end
end

local function updateMilkBottleCard()
	if not toolContainer then return end
	local card = toolContainer:FindFirstChild("MilkBottle")
	if not card then
		for _, child in ipairs(toolContainer:GetChildren()) do
			if child:IsA("Frame") then
				local buyBtn = child:FindFirstChild("BuyButton")
				if buyBtn and buyBtn:GetAttribute("ToolName") == "MilkBottle" then
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
	
	-- Update Buy Button Text
	local originalText = buyBtn.Text
	if originalText:find("Buy") or originalText:find("%$") then
		if originalText:find("Buy") then
			buyBtn.Text = "Buy ($" .. nextPrice .. ")"
		else
			buyBtn.Text = "$" .. nextPrice
		end
	else
		buyBtn.Text = "$" .. nextPrice
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
