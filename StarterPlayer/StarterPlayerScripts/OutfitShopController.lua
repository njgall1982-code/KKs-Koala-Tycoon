-- OutfitShopController.lua
-- Client-side controller that dynamically builds and manages the Outfit Shop GUI.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Configuration & Remote Events
local OutfitShopConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("OutfitShopConfig"))
local purchaseOutfitEvent = ReplicatedStorage:WaitForChild("PurchaseOutfitEvent")
local openOutfitShopEvent = ReplicatedStorage:WaitForChild("OpenOutfitShopEvent")

-- GUI elements
local screenGui
local mainFrame
local scrollingFrame
local statusLabel
local cards = {}

-- Create the GUI elements dynamically with premium styling
local function createShopGui()
	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "OutfitShopGui"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.DisplayOrder = 10
	screenGui.Parent = playerGui

	-- Dark Background Dimmer Overlay
	local overlay = Instance.new("Frame")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
	overlay.BackgroundTransparency = 1 -- Start transparent, tween to 0.55
	overlay.BorderSizePixel = 0
	overlay.Parent = screenGui

	-- Main Shop Frame
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "ShopFrame"
	mainFrame.Size = UDim2.new(0, 560, 0, 440)
	mainFrame.Position = UDim2.new(0.5, -280, 0.5, -220)
	mainFrame.BackgroundColor3 = Color3.fromRGB(24, 23, 28)
	mainFrame.BackgroundTransparency = 0.15 -- Glassmorphism look
	mainFrame.BorderSizePixel = 0
	mainFrame.ClipsDescendants = false
	mainFrame.Parent = screenGui

	-- Rounded Corners
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = mainFrame

	-- Thin glowing border stroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(56, 54, 66)
	stroke.Thickness = 1.5
	stroke.Parent = mainFrame

	-- Title
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -60, 0, 50)
	title.Position = UDim2.new(0, 20, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = "👗 KOALA OUTFIT SHOP"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.Parent = mainFrame

	-- Close Button
	local closeBtn = Instance.new("TextButton")
	closeBtn.Name = "CloseButton"
	closeBtn.Size = UDim2.new(0, 36, 0, 36)
	closeBtn.Position = UDim2.new(1, -46, 0, 10)
	closeBtn.BackgroundColor3 = Color3.fromRGB(40, 39, 46)
	closeBtn.Text = "✕"
	closeBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 14
	closeBtn.Parent = mainFrame

	local closeCorner = Instance.new("UICorner")
	closeCorner.CornerRadius = UDim.new(0, 10)
	closeCorner.Parent = closeBtn

	local closeStroke = Instance.new("UIStroke")
	closeStroke.Color = Color3.fromRGB(56, 54, 66)
	closeStroke.Thickness = 1
	closeStroke.Parent = closeBtn

	-- Close Button Hover Animation
	closeBtn.MouseEnter:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(0.2), {
			BackgroundColor3 = Color3.fromRGB(220, 60, 60),
			TextColor3 = Color3.new(1, 1, 1)
		}):Play()
	end)
	closeBtn.MouseLeave:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(0.2), {
			BackgroundColor3 = Color3.fromRGB(40, 39, 46),
			TextColor3 = Color3.fromRGB(200, 200, 200)
		}):Play()
	end)
	
	local OutfitShopController = {}
	
	function OutfitShopController.CloseShop()
		if not screenGui or not screenGui.Enabled then return end

		local overlay = screenGui.Overlay
		TweenService:Create(overlay, TweenInfo.new(0.2), {
			BackgroundTransparency = 1
		}):Play()

		local shrink = TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 0, 0, 0),
			Position = UDim2.new(0.5, 0, 0.5, 0)
		})
		shrink:Play()
		shrink.Completed:Connect(function()
			screenGui.Enabled = false
		end)
	end

	closeBtn.MouseButton1Click:Connect(function()
		OutfitShopController.CloseShop()
	end)

	-- Subtitle Info
	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.Size = UDim2.new(1, -40, 0, 20)
	subtitle.Position = UDim2.new(0, 20, 0, 42)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "Buy outfits to dress up your Adult Koalas (Stage 4). Outfits are consumable."
	subtitle.TextColor3 = Color3.fromRGB(150, 148, 160)
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.Font = Enum.Font.Gotham
	subtitle.TextSize = 11
	subtitle.Parent = mainFrame

	-- Container for cards
	scrollingFrame = Instance.new("ScrollingFrame")
	scrollingFrame.Name = "OutfitContainer"
	scrollingFrame.Size = UDim2.new(1, -40, 1, -130)
	scrollingFrame.Position = UDim2.new(0, 20, 0, 75)
	scrollingFrame.BackgroundTransparency = 1
	scrollingFrame.BorderSizePixel = 0
	scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	scrollingFrame.ScrollBarThickness = 6
	scrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 58, 72)
	scrollingFrame.Parent = mainFrame

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 155, 0, 165)
	gridLayout.CellPadding = UDim2.new(0, 16, 0, 16)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = scrollingFrame

	-- Auto-adjust CanvasSize
	gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, gridLayout.AbsoluteContentSize.Y + 20)
	end)

	-- Status Label for purchase logs
	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -40, 0, 30)
	statusLabel.Position = UDim2.new(0, 20, 1, -45)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Text = ""
	statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextSize = 13
	statusLabel.Visible = false
	statusLabel.Parent = mainFrame

	-- Populate Cards
	for idx, outfit in ipairs(OutfitShopConfig.GetAllOutfits()) do
		local card = Instance.new("Frame")
		card.Name = outfit.Name
		card.BackgroundColor3 = Color3.fromRGB(33, 31, 38)
		card.BorderSizePixel = 0
		card.LayoutOrder = idx
		card.Parent = scrollingFrame

		local cardCorner = Instance.new("UICorner")
		cardCorner.CornerRadius = UDim.new(0, 12)
		cardCorner.Parent = card

		local cardStroke = Instance.new("UIStroke")
		cardStroke.Color = Color3.fromRGB(50, 48, 59)
		cardStroke.Thickness = 1
		cardStroke.Parent = card

		-- Get Emoji/Prefix from DisplayName
		local emoji = outfit.DisplayName:match("^(%S+)") or "👕"

		local emojiLabel = Instance.new("TextLabel")
		emojiLabel.Size = UDim2.new(1, 0, 0.45, 0)
		emojiLabel.Position = UDim2.new(0, 0, 0.05, 0)
		emojiLabel.BackgroundTransparency = 1
		emojiLabel.Text = emoji
		emojiLabel.TextSize = 36
		emojiLabel.Parent = card

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -16, 0, 20)
		nameLabel.Position = UDim2.new(0, 8, 0.48, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = outfit.Name
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 12
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		nameLabel.Parent = card

		local quantityLabel = Instance.new("TextLabel")
		quantityLabel.Name = "QuantityLabel"
		quantityLabel.Size = UDim2.new(1, -16, 0, 16)
		quantityLabel.Position = UDim2.new(0, 8, 0.60, 0)
		quantityLabel.BackgroundTransparency = 1
		quantityLabel.Text = "Owned: 0"
		quantityLabel.TextColor3 = Color3.fromRGB(140, 138, 150)
		quantityLabel.Font = Enum.Font.Gotham
		quantityLabel.TextSize = 11
		quantityLabel.Parent = card

		local buyBtn = Instance.new("TextButton")
		buyBtn.Name = "BuyButton"
		buyBtn.Size = UDim2.new(1, -16, 0, 28)
		buyBtn.Position = UDim2.new(0, 8, 0.76, 0)
		buyBtn.BackgroundColor3 = Color3.fromRGB(90, 85, 219)
		buyBtn.Text = "Buy ($" .. outfit.Price .. ")"
		buyBtn.TextColor3 = Color3.new(1, 1, 1)
		buyBtn.Font = Enum.Font.GothamBold
		buyBtn.TextSize = 11
		buyBtn.Parent = card

		local btnCorner = Instance.new("UICorner")
		btnCorner.CornerRadius = UDim.new(0, 8)
		btnCorner.Parent = buyBtn

		-- Hover animations
		buyBtn.MouseEnter:Connect(function()
			TweenService:Create(buyBtn, TweenInfo.new(0.2), {
				BackgroundColor3 = Color3.fromRGB(110, 105, 235)
			}):Play()
		end)
		buyBtn.MouseLeave:Connect(function()
			TweenService:Create(buyBtn, TweenInfo.new(0.2), {
				BackgroundColor3 = Color3.fromRGB(90, 85, 219)
			}):Play()
		end)

		-- Button trigger
		buyBtn.MouseButton1Click:Connect(function()
			purchaseOutfitEvent:FireServer(outfit.Name, outfit.Price)
		end)

		cards[outfit.Name] = {
			card = card,
			quantityLabel = quantityLabel,
			buyBtn = buyBtn
		}
	end
	
	return OutfitShopController
end

-- Refresh UI quantities based on player attribute UnlockedOutfits
local function refreshInventory()
	if not screenGui then return end
	local unlockedStr = player:GetAttribute("UnlockedOutfits") or "{}"
	local unlocked = {}
	pcall(function()
		unlocked = HttpService:JSONDecode(unlockedStr)
	end)

	for name, cardData in pairs(cards) do
		local ownedCount = unlocked[name] or 0
		cardData.quantityLabel.Text = "Owned: " .. ownedCount
		
		if ownedCount > 0 then
			cardData.quantityLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
		else
			cardData.quantityLabel.TextColor3 = Color3.fromRGB(140, 138, 150)
		end
	end
end

local shopControllerInstance

-- Open Outfit Shop
local function openShop()
	if not screenGui then
		shopControllerInstance = createShopGui()
	end
	
	refreshInventory()
	screenGui.Enabled = true

	-- Fade & Scale Pop in Animation
	local overlay = screenGui.Overlay
	overlay.BackgroundTransparency = 1
	mainFrame.Size = UDim2.new(0, 0, 0, 0)
	mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)

	TweenService:Create(overlay, TweenInfo.new(0.3), {
		BackgroundTransparency = 0.55
	}):Play()

	TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 560, 0, 440),
		Position = UDim2.new(0.5, -280, 0.5, -220)
	}):Play()
end

-- Listen for server events
openOutfitShopEvent.OnClientEvent:Connect(openShop)

purchaseOutfitEvent.OnClientEvent:Connect(function(success, outfitName, message)
	if not statusLabel then return end

	statusLabel.Text = message
	statusLabel.Visible = true
	statusLabel.TextColor3 = success and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)

	task.delay(3, function()
		if statusLabel.Text == message then
			statusLabel.Visible = false
		end
	end)
end)

player:GetAttributeChangedSignal("UnlockedOutfits"):Connect(refreshInventory)

print("[OutfitShopController] Dynamic UI loaded.")
