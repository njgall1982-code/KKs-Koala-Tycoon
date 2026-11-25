-- ZooAnalyticsController.lua
-- Client-side controller that dynamically creates and manages the Tabbed Zoo Analytics Dashboard.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remotes
local openRemote = ReplicatedStorage:WaitForChild("OpenZooAnalytics")
local getDataRemote = ReplicatedStorage:WaitForChild("GetZooAnalyticsData")
local actionRemote = ReplicatedStorage:WaitForChild("ZooTerminalAction")
local renameRemote = ReplicatedStorage:WaitForChild("RenameExhibit")

-- State
local screenGui
local mainFrame
local overlay
local tabBarContainer
local contentContainer
local renameModal = nil
local isOpen = false
local currentData = nil
local activeTab = "Overview" -- "Overview" or exhibitName
local refreshThread = nil

-- Helpers
local function tween(instance, duration, properties, easingStyle)
	local info = TweenInfo.new(duration or 0.25, easingStyle or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local anim = TweenService:Create(instance, info, properties)
	anim:Play()
	return anim
end

local function getHappinessColor(score)
	if score >= 85 then
		return Color3.fromRGB(80, 220, 120), "Ecstatic"
	elseif score >= 50 then
		return Color3.fromRGB(240, 200, 60), "Content"
	elseif score >= 20 then
		return Color3.fromRGB(240, 130, 50), "Grumpy"
	else
		return Color3.fromRGB(240, 60, 60), "Starving"
	end
end

local function getRarityColor(rarity)
	if rarity == "Ultra Cute" then
		return Color3.fromRGB(220, 60, 255)
	elseif rarity == "Extra Cute" then
		return Color3.fromRGB(255, 200, 30)
	else
		return Color3.fromRGB(180, 180, 180)
	end
end

-- GUI Builder
local function createGui()
	if screenGui then return end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ZooAnalyticsGui"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.DisplayOrder = 15
	screenGui.Parent = playerGui

	-- Dark Background Dimmer
	overlay = Instance.new("TextButton")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(8, 10, 15)
	overlay.BackgroundTransparency = 1
	overlay.Text = ""
	overlay.BorderSizePixel = 0
	overlay.Parent = screenGui

	-- Main Window Frame
	mainFrame = Instance.new("Frame")
	mainFrame.Name = "TerminalWindow"
	mainFrame.Size = UDim2.new(0, 720, 0, 560)
	mainFrame.Position = UDim2.new(0.5, -360, 0.5, -280)
	mainFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	mainFrame.BackgroundTransparency = 0.05
	mainFrame.BorderSizePixel = 0
	mainFrame.ClipsDescendants = true
	mainFrame.Parent = screenGui

	local corner = Instance.new("UICorner", mainFrame)
	corner.CornerRadius = UDim.new(0, 14)

	local stroke = Instance.new("UIStroke", mainFrame)
	stroke.Color = Color3.fromRGB(50, 70, 95)
	stroke.Thickness = 1.5

	-- Header
	local header = Instance.new("Frame", mainFrame)
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 52)
	header.BackgroundColor3 = Color3.fromRGB(26, 32, 44)
	header.BorderSizePixel = 0

	local headerCorner = Instance.new("UICorner", header)
	headerCorner.CornerRadius = UDim.new(0, 14)

	local headerBottomSquare = Instance.new("Frame", header)
	headerBottomSquare.Size = UDim2.new(1, 0, 0, 14)
	headerBottomSquare.Position = UDim2.new(0, 0, 1, -14)
	headerBottomSquare.BackgroundColor3 = Color3.fromRGB(26, 32, 44)
	headerBottomSquare.BorderSizePixel = 0

	local title = Instance.new("TextLabel", header)
	title.Name = "Title"
	title.Text = "Zoo Operations & Revenue Terminal"
	title.TextColor3 = Color3.fromRGB(240, 245, 255)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 17
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 20, 0, 0)
	title.Size = UDim2.new(0.8, 0, 1, 0)

	-- Standard ASCII "X" Close Button (Never missing font glyph)
	local closeBtn = Instance.new("TextButton", header)
	closeBtn.Name = "CloseBtn"
	closeBtn.Text = "X"
	closeBtn.TextColor3 = Color3.fromRGB(210, 220, 235)
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 16
	closeBtn.Size = UDim2.new(0, 32, 0, 32)
	closeBtn.Position = UDim2.new(1, -44, 0.5, -16)
	closeBtn.BackgroundColor3 = Color3.fromRGB(40, 48, 64)
	closeBtn.BorderSizePixel = 0
	local closeCorner = Instance.new("UICorner", closeBtn)
	closeCorner.CornerRadius = UDim.new(0, 8)

	closeBtn.MouseButton1Click:Connect(function()
		hideDashboard()
	end)
	overlay.MouseButton1Click:Connect(function()
		hideDashboard()
	end)

	-- Tab Bar Container
	tabBarContainer = Instance.new("Frame", mainFrame)
	tabBarContainer.Name = "TabBar"
	tabBarContainer.Size = UDim2.new(1, -40, 0, 36)
	tabBarContainer.Position = UDim2.new(0, 20, 0, 58)
	tabBarContainer.BackgroundTransparency = 1

	local tabLayout = Instance.new("UIListLayout", tabBarContainer)
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder

	-- Content Container
	contentContainer = Instance.new("Frame", mainFrame)
	contentContainer.Name = "Content"
	contentContainer.Size = UDim2.new(1, -40, 1, -106)
	contentContainer.Position = UDim2.new(0, 20, 0, 98)
	contentContainer.BackgroundTransparency = 1
end

local function clearContent()
	if not contentContainer then return end
	for _, child in ipairs(contentContainer:GetChildren()) do
		child:Destroy()
	end
end

local function clearTabBar()
	if not tabBarContainer then return end
	for _, child in ipairs(tabBarContainer:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function closeRenameModal()
	if renameModal then
		renameModal:Destroy()
		renameModal = nil
	end
end

-- Forward declaration
local renderView
local renderTabBar

-- Clean Popup Modal for Renaming Exhibits
local function openRenameModal(exh)
	closeRenameModal()

	-- Dark blocker overlay covering mainFrame
	renameModal = Instance.new("TextButton", mainFrame)
	renameModal.Name = "RenameModalOverlay"
	renameModal.Size = UDim2.new(1, 0, 1, 0)
	renameModal.Position = UDim2.new(0, 0, 0, 0)
	renameModal.BackgroundColor3 = Color3.fromRGB(5, 8, 12)
	renameModal.BackgroundTransparency = 0.45
	renameModal.Text = ""
	renameModal.AutoButtonColor = false
	renameModal.BorderSizePixel = 0
	renameModal.ZIndex = 50

	local modalBox = Instance.new("Frame", renameModal)
	modalBox.Name = "RenameBox"
	modalBox.Size = UDim2.new(0, 420, 0, 210)
	modalBox.Position = UDim2.new(0.5, -210, 0.5, -105)
	modalBox.BackgroundColor3 = Color3.fromRGB(24, 30, 42)
	modalBox.BorderSizePixel = 0
	modalBox.ZIndex = 51

	local mCorner = Instance.new("UICorner", modalBox)
	mCorner.CornerRadius = UDim.new(0, 12)

	local mStroke = Instance.new("UIStroke", modalBox)
	mStroke.Color = Color3.fromRGB(55, 75, 105)
	mStroke.Thickness = 1.5

	-- Modal Header
	local mTitle = Instance.new("TextLabel", modalBox)
	mTitle.Text = "Rename Exhibit"
	mTitle.TextColor3 = Color3.fromRGB(245, 250, 255)
	mTitle.Font = Enum.Font.GothamBold
	mTitle.TextSize = 16
	mTitle.Position = UDim2.new(0, 20, 0, 16)
	mTitle.Size = UDim2.new(1, -70, 0, 22)
	mTitle.TextXAlignment = Enum.TextXAlignment.Left
	mTitle.BackgroundTransparency = 1
	mTitle.ZIndex = 52

	-- Modal Close "X" Button
	local mClose = Instance.new("TextButton", modalBox)
	mClose.Name = "ModalCloseBtn"
	mClose.Text = "X"
	mClose.TextColor3 = Color3.fromRGB(180, 195, 215)
	mClose.Font = Enum.Font.GothamBold
	mClose.TextSize = 14
	mClose.Size = UDim2.new(0, 26, 0, 26)
	mClose.Position = UDim2.new(1, -38, 0, 14)
	mClose.BackgroundColor3 = Color3.fromRGB(35, 42, 58)
	mClose.BorderSizePixel = 0
	mClose.ZIndex = 52
	local mcCorner = Instance.new("UICorner", mClose)
	mcCorner.CornerRadius = UDim.new(0, 6)
	mClose.MouseButton1Click:Connect(closeRenameModal)

	-- Subtitle
	local mSub = Instance.new("TextLabel", modalBox)
	mSub.Text = "Enter a new name for " .. exh.displayName .. ":"
	mSub.TextColor3 = Color3.fromRGB(150, 165, 185)
	mSub.Font = Enum.Font.Gotham
	mSub.TextSize = 13
	mSub.Position = UDim2.new(0, 20, 0, 44)
	mSub.Size = UDim2.new(1, -40, 0, 20)
	mSub.TextXAlignment = Enum.TextXAlignment.Left
	mSub.BackgroundTransparency = 1
	mSub.ZIndex = 52

	-- Input Box
	local input = Instance.new("TextBox", modalBox)
	input.Name = "ExhibitNameInput"
	input.Text = exh.displayName
	input.PlaceholderText = "New exhibit name..."
	input.PlaceholderColor3 = Color3.fromRGB(110, 125, 145)
	input.TextColor3 = Color3.fromRGB(255, 255, 255)
	input.Font = Enum.Font.GothamMedium
	input.TextSize = 14
	input.Size = UDim2.new(1, -40, 0, 38)
	input.Position = UDim2.new(0, 20, 0, 76)
	input.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
	input.BorderSizePixel = 0
	input.ClearTextOnFocus = false
	input.ZIndex = 52

	local inCorner = Instance.new("UICorner", input)
	inCorner.CornerRadius = UDim.new(0, 8)

	local inStroke = Instance.new("UIStroke", input)
	inStroke.Color = Color3.fromRGB(45, 65, 92)
	inStroke.Thickness = 1

	local inPad = Instance.new("UIPadding", input)
	inPad.PaddingLeft = UDim.new(0, 12)
	inPad.PaddingRight = UDim.new(0, 12)

	-- Button Row
	local btnRow = Instance.new("Frame", modalBox)
	btnRow.Size = UDim2.new(1, -40, 0, 38)
	btnRow.Position = UDim2.new(0, 20, 0, 134)
	btnRow.BackgroundTransparency = 1
	btnRow.ZIndex = 52

	local cancelBtn = Instance.new("TextButton", btnRow)
	cancelBtn.Text = "Cancel"
	cancelBtn.TextColor3 = Color3.fromRGB(180, 195, 215)
	cancelBtn.Font = Enum.Font.GothamBold
	cancelBtn.TextSize = 13
	cancelBtn.Size = UDim2.new(0.48, -6, 1, 0)
	cancelBtn.Position = UDim2.new(0, 0, 0, 0)
	cancelBtn.BackgroundColor3 = Color3.fromRGB(38, 46, 62)
	cancelBtn.BorderSizePixel = 0
	cancelBtn.ZIndex = 52
	local cCorner = Instance.new("UICorner", cancelBtn)
	cCorner.CornerRadius = UDim.new(0, 8)

	local saveBtn = Instance.new("TextButton", btnRow)
	saveBtn.Text = "Save Name"
	saveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	saveBtn.Font = Enum.Font.GothamBold
	saveBtn.TextSize = 13
	saveBtn.Size = UDim2.new(0.52, -6, 1, 0)
	saveBtn.Position = UDim2.new(0.48, 12, 0, 0)
	saveBtn.BackgroundColor3 = Color3.fromRGB(45, 160, 75)
	saveBtn.BorderSizePixel = 0
	saveBtn.ZIndex = 52
	local sCorner = Instance.new("UICorner", saveBtn)
	sCorner.CornerRadius = UDim.new(0, 8)

	local function doSave()
		local newName = input.Text:match("^%s*(.-)%s*$")
		if newName and newName ~= "" and exh.exhibitPath then
			renameRemote:FireServer(exh.exhibitPath, newName)
			exh.displayName = newName
			closeRenameModal()
			renderTabBar(currentData)
			renderView(currentData)
		end
	end

	cancelBtn.MouseButton1Click:Connect(closeRenameModal)
	saveBtn.MouseButton1Click:Connect(doSave)

	input.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			doSave()
		end
	end)

	input:CaptureFocus()
end

-- Re-renders Tab Bar Buttons
function renderTabBar(data)
	clearTabBar()
	if not data.isTerminalUnlocked then
		tabBarContainer.Visible = false
		return
	end
	tabBarContainer.Visible = true

	local function createTabBtn(order, tabKey, labelText, isLocked)
		local btn = Instance.new("TextButton", tabBarContainer)
		btn.Name = "Tab_" .. tabKey
		btn.LayoutOrder = order
		btn.Size = UDim2.new(0, 0, 1, 0)
		btn.AutomaticSize = Enum.AutomaticSize.X
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 13
		btn.BorderSizePixel = 0

		local pad = Instance.new("UIPadding", btn)
		pad.PaddingLeft = UDim.new(0, 14)
		pad.PaddingRight = UDim.new(0, 14)

		local bCorner = Instance.new("UICorner", btn)
		bCorner.CornerRadius = UDim.new(0, 8)

		local bStroke = Instance.new("UIStroke", btn)
		bStroke.Thickness = 1

		local isActive = (activeTab == tabKey)
		if isActive then
			btn.BackgroundColor3 = Color3.fromRGB(40, 70, 110)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			bStroke.Color = Color3.fromRGB(70, 140, 230)
		else
			btn.BackgroundColor3 = Color3.fromRGB(26, 32, 44)
			btn.TextColor3 = Color3.fromRGB(160, 175, 195)
			bStroke.Color = Color3.fromRGB(40, 50, 70)
		end

		local display = labelText
		if isLocked then
			display = display .. " [Locked]"
		end
		btn.Text = display

		btn.MouseButton1Click:Connect(function()
			activeTab = tabKey
			closeRenameModal()
			renderTabBar(currentData)
			renderView(currentData)
		end)

		return btn
	end

	-- Overview Tab
	createTabBtn(1, "Overview", "Overview", false)

	-- Exhibit Tabs
	for i, exh in ipairs(data.exhibits) do
		local isLocked = (not exh.isTelemetryUnlocked) and (not exh.isDiagnosticsUnlocked)
		createTabBtn(i + 1, exh.name, exh.displayName, isLocked)
	end
end

-- Renders Locked Screen
local function renderLockedScreen(data)
	clearContent()
	tabBarContainer.Visible = false

	local centerFrame = Instance.new("Frame", contentContainer)
	centerFrame.Size = UDim2.new(1, 0, 1, 0)
	centerFrame.BackgroundTransparency = 1

	local icon = Instance.new("TextLabel", centerFrame)
	icon.Text = "[LOCKED]"
	icon.TextColor3 = Color3.fromRGB(180, 195, 220)
	icon.Font = Enum.Font.GothamBold
	icon.TextSize = 32
	icon.Size = UDim2.new(1, 0, 0, 50)
	icon.Position = UDim2.new(0, 0, 0.12, 0)
	icon.BackgroundTransparency = 1

	local heading = Instance.new("TextLabel", centerFrame)
	heading.Text = "Zoo Analytics Terminal Locked"
	heading.TextColor3 = Color3.fromRGB(255, 255, 255)
	heading.Font = Enum.Font.GothamBold
	heading.TextSize = 22
	heading.Size = UDim2.new(1, 0, 0, 30)
	heading.Position = UDim2.new(0, 0, 0.28, 0)
	heading.BackgroundTransparency = 1

	local desc = Instance.new("TextLabel", centerFrame)
	desc.Text = "Upgrade your zoo office terminal to monitor park revenue rates, diagnose animal happiness factors, and unlock live exhibit telemetry drill-downs."
	desc.TextColor3 = Color3.fromRGB(180, 190, 205)
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 14
	desc.TextWrapped = true
	desc.Size = UDim2.new(0.8, 0, 0, 60)
	desc.Position = UDim2.new(0.1, 0, 0.38, 0)
	desc.BackgroundTransparency = 1

	local unlockBtn = Instance.new("TextButton", centerFrame)
	unlockBtn.Name = "UnlockBtn"
	unlockBtn.Text = string.format("Unlock Zoo Analytics Terminal ($%d Cash)", data.terminalCost or 350)
	unlockBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	unlockBtn.Font = Enum.Font.GothamBold
	unlockBtn.TextSize = 16
	unlockBtn.Size = UDim2.new(0, 420, 0, 50)
	unlockBtn.Position = UDim2.new(0.5, -210, 0.62, 0)
	unlockBtn.BackgroundColor3 = Color3.fromRGB(45, 170, 75)
	unlockBtn.BorderSizePixel = 0

	local btnCorner = Instance.new("UICorner", unlockBtn)
	btnCorner.CornerRadius = UDim.new(0, 10)

	local statusMsg = Instance.new("TextLabel", centerFrame)
	statusMsg.Name = "StatusMsg"
	statusMsg.Text = ""
	statusMsg.TextColor3 = Color3.fromRGB(255, 80, 80)
	statusMsg.Font = Enum.Font.GothamMedium
	statusMsg.TextSize = 14
	statusMsg.Size = UDim2.new(1, 0, 0, 24)
	statusMsg.Position = UDim2.new(0, 0, 0.76, 0)
	statusMsg.BackgroundTransparency = 1

	unlockBtn.MouseButton1Click:Connect(function()
		unlockBtn.Active = false
		unlockBtn.Text = "Processing Purchase..."
		local success, newPayload = actionRemote:InvokeServer("UnlockTerminal")
		if success and type(newPayload) == "table" then
			currentData = newPayload
			activeTab = "Overview"
			renderTabBar(newPayload)
			renderView(newPayload)
		else
			unlockBtn.Active = true
			unlockBtn.Text = string.format("Unlock Zoo Analytics Terminal ($%d Cash)", data.terminalCost or 350)
			statusMsg.Text = tostring(newPayload or "Payment failed! Check your Cash.")
		end
	end)
end

-- Renders Overview Tab
local function renderOverviewTab(data)
	clearContent()

	-- 1. Executive Top Metrics Row
	local metricsRow = Instance.new("Frame", contentContainer)
	metricsRow.Name = "MetricsRow"
	metricsRow.Size = UDim2.new(1, 0, 0, 92)
	metricsRow.BackgroundTransparency = 1

	local rowLayout = Instance.new("UIListLayout", metricsRow)
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.Padding = UDim.new(0, 12)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local function createMetricCard(order, titleText, valueText, subText, valueColor)
		local card = Instance.new("Frame", metricsRow)
		card.Size = UDim2.new(0.315, 0, 1, 0)
		card.BackgroundColor3 = Color3.fromRGB(28, 35, 48)
		card.BorderSizePixel = 0
		card.LayoutOrder = order

		local cCorner = Instance.new("UICorner", card)
		cCorner.CornerRadius = UDim.new(0, 10)

		local cStroke = Instance.new("UIStroke", card)
		cStroke.Color = Color3.fromRGB(45, 58, 78)
		cStroke.Thickness = 1

		local lblTitle = Instance.new("TextLabel", card)
		lblTitle.Text = titleText
		lblTitle.TextColor3 = Color3.fromRGB(160, 175, 195)
		lblTitle.Font = Enum.Font.GothamMedium
		lblTitle.TextSize = 12
		lblTitle.Size = UDim2.new(1, -20, 0, 20)
		lblTitle.Position = UDim2.new(0, 10, 0, 8)
		lblTitle.TextXAlignment = Enum.TextXAlignment.Left
		lblTitle.BackgroundTransparency = 1

		local lblVal = Instance.new("TextLabel", card)
		lblVal.Text = valueText
		lblVal.TextColor3 = valueColor or Color3.fromRGB(255, 255, 255)
		lblVal.Font = Enum.Font.GothamBold
		lblVal.TextSize = 20
		lblVal.Size = UDim2.new(1, -20, 0, 30)
		lblVal.Position = UDim2.new(0, 10, 0, 28)
		lblVal.TextXAlignment = Enum.TextXAlignment.Left
		lblVal.BackgroundTransparency = 1

		local lblSub = Instance.new("TextLabel", card)
		lblSub.Text = subText
		lblSub.TextColor3 = Color3.fromRGB(130, 145, 165)
		lblSub.Font = Enum.Font.Gotham
		lblSub.TextSize = 11
		lblSub.Size = UDim2.new(1, -20, 0, 18)
		lblSub.Position = UDim2.new(0, 10, 0, 60)
		lblSub.TextXAlignment = Enum.TextXAlignment.Left
		lblSub.BackgroundTransparency = 1

		return card
	end

	createMetricCard(1, "TOTAL CASH FLOW", string.format("+$%d / 5s", data.totalRevenueRate or 0), string.format("~$%d / min", data.totalRevenuePerMin or 0), Color3.fromRGB(90, 230, 120))
	local happyColor, happyMood = getHappinessColor(data.averageHappiness or 100)
	createMetricCard(2, "PARK HAPPINESS", string.format("%d%%", data.averageHappiness or 100), happyMood, happyColor)
	createMetricCard(3, "KOALA POPULATION", string.format("%d Koalas", data.totalKoalas or 0), string.format("Across %d Exhibits", #data.exhibits), Color3.fromRGB(100, 200, 255))

	-- 2. Section Header
	local sectionLbl = Instance.new("TextLabel", contentContainer)
	sectionLbl.Text = "EXHIBIT ROSTER & STATUS"
	sectionLbl.TextColor3 = Color3.fromRGB(150, 165, 185)
	sectionLbl.Font = Enum.Font.GothamBold
	sectionLbl.TextSize = 13
	sectionLbl.TextXAlignment = Enum.TextXAlignment.Left
	sectionLbl.Size = UDim2.new(1, 0, 0, 24)
	sectionLbl.Position = UDim2.new(0, 0, 0, 102)
	sectionLbl.BackgroundTransparency = 1

	-- 3. Scrollable Exhibit Overview List
	local scroll = Instance.new("ScrollingFrame", contentContainer)
	scroll.Name = "ExhibitOverviewScroll"
	scroll.Size = UDim2.new(1, 0, 1, -132)
	scroll.Position = UDim2.new(0, 0, 0, 132)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Color3.fromRGB(60, 75, 100)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)

	local listLayout = Instance.new("UIListLayout", scroll)
	listLayout.Padding = UDim.new(0, 10)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder

	for i, exh in ipairs(data.exhibits) do
		local card = Instance.new("Frame", scroll)
		card.Size = UDim2.new(1, -10, 0, 72)
		card.BackgroundColor3 = Color3.fromRGB(25, 32, 44)
		card.BorderSizePixel = 0
		card.LayoutOrder = i

		local cCorner = Instance.new("UICorner", card)
		cCorner.CornerRadius = UDim.new(0, 10)

		local cStroke = Instance.new("UIStroke", card)
		cStroke.Color = Color3.fromRGB(45, 58, 80)
		cStroke.Thickness = 1

		local nameLabel = Instance.new("TextLabel", card)
		nameLabel.Text = exh.displayName
		nameLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 15
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Position = UDim2.new(0, 14, 0, 12)
		nameLabel.Size = UDim2.new(0.5, 0, 0, 20)
		nameLabel.BackgroundTransparency = 1

		local foodPct = math.floor((exh.foodLevel / math.max(exh.maxFoodLevel, 1)) * 100)
		local exhHappyColor, _ = getHappinessColor(exh.averageHappiness)

		local subText = Instance.new("TextLabel", card)
		subText.Text = string.format("Food: %d%%  |  Koalas: %d/%d  |  Happiness: %d%%  |  +$%d/5s", foodPct, exh.koalaCount, exh.maxKoalas, exh.averageHappiness, exh.revenue)
		subText.TextColor3 = Color3.fromRGB(160, 175, 195)
		subText.Font = Enum.Font.GothamMedium
		subText.TextSize = 12
		subText.TextXAlignment = Enum.TextXAlignment.Left
		subText.Position = UDim2.new(0, 14, 0, 36)
		subText.Size = UDim2.new(0.65, 0, 0, 20)
		subText.BackgroundTransparency = 1

		-- View Tab Button (Clean text, no missing glyphs)
		local jumpBtn = Instance.new("TextButton", card)
		local isLocked = (not exh.isTelemetryUnlocked) and (not exh.isDiagnosticsUnlocked)
		jumpBtn.Text = isLocked and "View Details [Locked]" or "View Exhibit >"
		jumpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		jumpBtn.Font = Enum.Font.GothamBold
		jumpBtn.TextSize = 12
		jumpBtn.Size = UDim2.new(0, 140, 0, 32)
		jumpBtn.Position = UDim2.new(1, -154, 0.5, -16)
		jumpBtn.BackgroundColor3 = isLocked and Color3.fromRGB(45, 55, 75) or Color3.fromRGB(40, 110, 200)
		jumpBtn.BorderSizePixel = 0

		local jCorner = Instance.new("UICorner", jumpBtn)
		jCorner.CornerRadius = UDim.new(0, 6)

		jumpBtn.MouseButton1Click:Connect(function()
			activeTab = exh.name
			closeRenameModal()
			renderTabBar(currentData)
			renderView(currentData)
		end)
	end
end

-- Renders Specific Exhibit Tab
local function renderExhibitTab(data, exhibitName)
	clearContent()

	local exh = nil
	for _, e in ipairs(data.exhibits) do
		if e.name == exhibitName then
			exh = e
			break
		end
	end

	if not exh then
		local missing = Instance.new("TextLabel", contentContainer)
		missing.Text = "Exhibit not found."
		missing.TextColor3 = Color3.fromRGB(200, 200, 200)
		missing.Size = UDim2.new(1, 0, 1, 0)
		missing.BackgroundTransparency = 1
		return
	end

	-- Top Bar: Exhibit Name & Clean Rename Button (No permanent text box)
	local topBar = Instance.new("Frame", contentContainer)
	topBar.Size = UDim2.new(1, 0, 0, 48)
	topBar.BackgroundColor3 = Color3.fromRGB(25, 32, 44)
	topBar.BorderSizePixel = 0

	local tbCorner = Instance.new("UICorner", topBar)
	tbCorner.CornerRadius = UDim.new(0, 10)

	local titleLbl = Instance.new("TextLabel", topBar)
	titleLbl.Text = exh.displayName
	titleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 16
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Position = UDim2.new(0, 16, 0, 0)
	titleLbl.Size = UDim2.new(1, -130, 1, 0)
	titleLbl.BackgroundTransparency = 1

	-- Rename Button that opens the modal
	local renameBtn = Instance.new("TextButton", topBar)
	renameBtn.Name = "RenameBtn"
	renameBtn.Text = "Rename"
	renameBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	renameBtn.Font = Enum.Font.GothamBold
	renameBtn.TextSize = 13
	renameBtn.Position = UDim2.new(1, -100, 0.5, -16)
	renameBtn.Size = UDim2.new(0, 86, 0, 32)
	renameBtn.BackgroundColor3 = Color3.fromRGB(40, 110, 200)
	renameBtn.BorderSizePixel = 0

	local rbCorner = Instance.new("UICorner", renameBtn)
	rbCorner.CornerRadius = UDim.new(0, 6)

	renameBtn.MouseButton1Click:Connect(function()
		openRenameModal(exh)
	end)

	-- Scrollable Exhibit Details
	local scroll = Instance.new("ScrollingFrame", contentContainer)
	scroll.Name = "ExhibitDetailScroll"
	scroll.Size = UDim2.new(1, 0, 1, -56)
	scroll.Position = UDim2.new(0, 0, 0, 56)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = Color3.fromRGB(60, 75, 100)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)

	local sLayout = Instance.new("UIListLayout", scroll)
	sLayout.Padding = UDim.new(0, 12)
	sLayout.SortOrder = Enum.SortOrder.LayoutOrder

	-- 1. Stats Ribbon (Food, Koalas, Live Revenue, Happiness)
	local ribbon = Instance.new("Frame", scroll)
	ribbon.Size = UDim2.new(1, -10, 0, 48)
	ribbon.BackgroundColor3 = Color3.fromRGB(24, 30, 42)
	ribbon.BorderSizePixel = 0
	ribbon.LayoutOrder = 1

	local ribCorner = Instance.new("UICorner", ribbon)
	ribCorner.CornerRadius = UDim.new(0, 8)

	local foodPct = math.floor((exh.foodLevel / math.max(exh.maxFoodLevel, 1)) * 100)
	local happyColor, happyMood = getHappinessColor(exh.averageHappiness)

	local ribText = Instance.new("TextLabel", ribbon)
	ribText.Text = string.format("Food: %d%%  |  Capacity: %d/%d  |  Income: +$%d/5s  |  Mood: %d%% (%s)",
		foodPct, exh.koalaCount, exh.maxKoalas, exh.revenue, exh.averageHappiness, happyMood)
	ribText.TextColor3 = Color3.fromRGB(220, 230, 245)
	ribText.Font = Enum.Font.GothamMedium
	ribText.TextSize = 13
	ribText.Size = UDim2.new(1, -20, 1, 0)
	ribText.Position = UDim2.new(0, 10, 0, 0)
	ribText.TextXAlignment = Enum.TextXAlignment.Left
	ribText.BackgroundTransparency = 1

	-- 2. HAPPINESS DIAGNOSTICS SECTION (Separate Unlock)
	if not exh.isDiagnosticsUnlocked then
		local diagLockCard = Instance.new("Frame", scroll)
		diagLockCard.Size = UDim2.new(1, -10, 0, 140)
		diagLockCard.BackgroundColor3 = Color3.fromRGB(22, 28, 38)
		diagLockCard.BorderSizePixel = 0
		diagLockCard.LayoutOrder = 2

		local dlcCorner = Instance.new("UICorner", diagLockCard)
		dlcCorner.CornerRadius = UDim.new(0, 10)

		local dlcStroke = Instance.new("UIStroke", diagLockCard)
		dlcStroke.Color = Color3.fromRGB(50, 70, 95)
		dlcStroke.Thickness = 1

		local dlTitle = Instance.new("TextLabel", diagLockCard)
		dlTitle.Text = "Happiness Diagnostics [Locked]"
		dlTitle.TextColor3 = Color3.fromRGB(240, 245, 255)
		dlTitle.Font = Enum.Font.GothamBold
		dlTitle.TextSize = 15
		dlTitle.Position = UDim2.new(0, 16, 0, 14)
		dlTitle.Size = UDim2.new(1, -32, 0, 22)
		dlTitle.TextXAlignment = Enum.TextXAlignment.Left
		dlTitle.BackgroundTransparency = 1

		local dlDesc = Instance.new("TextLabel", diagLockCard)
		dlDesc.Text = "Unlock diagnostic telemetry to uncover why animal happiness isn't higher, with detailed scoring and actionable tips on food supply, cuddle care, and social bonuses."
		dlDesc.TextColor3 = Color3.fromRGB(160, 175, 195)
		dlDesc.Font = Enum.Font.Gotham
		dlDesc.TextSize = 12
		dlDesc.TextWrapped = true
		dlDesc.Position = UDim2.new(0, 16, 0, 38)
		dlDesc.Size = UDim2.new(1, -32, 0, 36)
		dlDesc.TextXAlignment = Enum.TextXAlignment.Left
		dlDesc.BackgroundTransparency = 1

		local unlockDiagBtn = Instance.new("TextButton", diagLockCard)
		unlockDiagBtn.Text = string.format("Unlock Happiness Diagnostics ($%d Cash)", data.diagnosticsCost or 200)
		unlockDiagBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		unlockDiagBtn.Font = Enum.Font.GothamBold
		unlockDiagBtn.TextSize = 13
		unlockDiagBtn.Size = UDim2.new(0, 300, 0, 34)
		unlockDiagBtn.Position = UDim2.new(0, 16, 0, 88)
		unlockDiagBtn.BackgroundColor3 = Color3.fromRGB(45, 120, 210)
		unlockDiagBtn.BorderSizePixel = 0

		local udCorner = Instance.new("UICorner", unlockDiagBtn)
		udCorner.CornerRadius = UDim.new(0, 6)

		unlockDiagBtn.MouseButton1Click:Connect(function()
			unlockDiagBtn.Active = false
			unlockDiagBtn.Text = "Unlocking..."
			local success, newPayload = actionRemote:InvokeServer("UnlockExhibitDiagnostics", exh.name)
			if success and type(newPayload) == "table" then
				currentData = newPayload
				renderTabBar(newPayload)
				renderView(newPayload)
			else
				unlockDiagBtn.Active = true
				unlockDiagBtn.Text = string.format("Unlock Happiness Diagnostics ($%d Cash)", data.diagnosticsCost or 200)
			end
		end)

	else
		-- UNLOCKED HAPPINESS DIAGNOSTICS
		local diagCard = Instance.new("Frame", scroll)
		diagCard.Size = UDim2.new(1, -10, 0, 140)
		diagCard.BackgroundColor3 = Color3.fromRGB(22, 28, 38)
		diagCard.BorderSizePixel = 0
		diagCard.LayoutOrder = 2

		local dcCorner = Instance.new("UICorner", diagCard)
		dcCorner.CornerRadius = UDim.new(0, 10)

		local dcStroke = Instance.new("UIStroke", diagCard)
		dcStroke.Color = Color3.fromRGB(50, 70, 95)
		dcStroke.Thickness = 1

		local diagHeader = Instance.new("TextLabel", diagCard)
		diagHeader.Text = "HAPPINESS DIAGNOSTICS: WHY ISN'T HAPPINESS HIGHER?"
		diagHeader.TextColor3 = Color3.fromRGB(150, 185, 230)
		diagHeader.Font = Enum.Font.GothamBold
		diagHeader.TextSize = 12
		diagHeader.Position = UDim2.new(0, 14, 0, 8)
		diagHeader.Size = UDim2.new(1, -28, 0, 20)
		diagHeader.TextXAlignment = Enum.TextXAlignment.Left
		diagHeader.BackgroundTransparency = 1

		local bd = exh.happinessBreakdown or {
			foodScore = 30, foodMax = 60,
			cuddleScore = 0, cuddleMax = 25, cuddledCount = 0,
			socialScore = 8, socialMax = 15, totalHappiness = 50
		}

		local function createFactorRow(yPos, factorName, score, maxScore, tipText)
			local row = Instance.new("Frame", diagCard)
			row.Size = UDim2.new(1, -28, 0, 28)
			row.Position = UDim2.new(0, 14, 0, yPos)
			row.BackgroundTransparency = 1

			local titleLbl = Instance.new("TextLabel", row)
			titleLbl.Text = string.format("%s: +%d / %d pts", factorName, score, maxScore)
			titleLbl.TextColor3 = (score >= maxScore * 0.7) and Color3.fromRGB(90, 220, 120) or ((score > 0) and Color3.fromRGB(120, 200, 255) or Color3.fromRGB(240, 180, 60))
			titleLbl.Font = Enum.Font.GothamBold
			titleLbl.TextSize = 12
			titleLbl.Size = UDim2.new(0.36, 0, 1, 0)
			titleLbl.TextXAlignment = Enum.TextXAlignment.Left
			titleLbl.BackgroundTransparency = 1

			local tipLbl = Instance.new("TextLabel", row)
			tipLbl.Text = "- " .. tipText
			tipLbl.TextColor3 = Color3.fromRGB(170, 185, 205)
			tipLbl.Font = Enum.Font.Gotham
			tipLbl.TextSize = 12
			tipLbl.Position = UDim2.new(0.38, 0, 0, 0)
			tipLbl.Size = UDim2.new(0.62, 0, 1, 0)
			tipLbl.TextXAlignment = Enum.TextXAlignment.Left
			tipLbl.BackgroundTransparency = 1
		end

		local foodTip = (bd.foodScore >= 50) and "Trough is well stocked with leaves." or "Trough low! Refill trough with Feed Bag to reach +60 pts."
		createFactorRow(32, "Food Supply", bd.foodScore, bd.foodMax, foodTip)

		-- Dynamic Cuddle Tip with scaling details
		local cuddleTip = ""
		local cuddled = bd.cuddledCount or 0
		local totalInExh = exh.koalaCount or 0
		if totalInExh == 0 then
			cuddleTip = "No koalas in exhibit to cuddle."
		elseif cuddled == 0 then
			cuddleTip = "None cuddled recently. Cuddle koalas for up to +25 pts!"
		elseif cuddled < totalInExh then
			cuddleTip = string.format("%d of %d cuddled (+%d pts). Cuddle the rest for full +25 pts!", cuddled, totalInExh, bd.cuddleScore)
		else
			cuddleTip = string.format("All %d koalas actively cuddled (+25 pts boost)!", totalInExh)
		end
		createFactorRow(64, "Cuddle Care", bd.cuddleScore, bd.cuddleMax, cuddleTip)

		local socialTip = (exh.koalaCount >= 2) and "Social companions present (friends boost happiness)." or "Add a 2nd koala to this exhibit for the +15 pts social bonus."
		createFactorRow(96, "Social Group", bd.socialScore, bd.socialMax, socialTip)
	end

	-- 3. KOALA TELEMETRY ROSTER SECTION (Separate Unlock)
	if not exh.isTelemetryUnlocked then
		local teleLockCard = Instance.new("Frame", scroll)
		teleLockCard.Size = UDim2.new(1, -10, 0, 140)
		teleLockCard.BackgroundColor3 = Color3.fromRGB(22, 28, 38)
		teleLockCard.BorderSizePixel = 0
		teleLockCard.LayoutOrder = 3

		local tlcCorner = Instance.new("UICorner", teleLockCard)
		tlcCorner.CornerRadius = UDim.new(0, 10)

		local tlcStroke = Instance.new("UIStroke", teleLockCard)
		tlcStroke.Color = Color3.fromRGB(50, 70, 95)
		tlcStroke.Thickness = 1

		local tlTitle = Instance.new("TextLabel", teleLockCard)
		tlTitle.Text = "Koala Roster Telemetry [Locked]"
		tlTitle.TextColor3 = Color3.fromRGB(240, 245, 255)
		tlTitle.Font = Enum.Font.GothamBold
		tlTitle.TextSize = 15
		tlTitle.Position = UDim2.new(0, 16, 0, 14)
		tlTitle.Size = UDim2.new(1, -32, 0, 22)
		tlTitle.TextXAlignment = Enum.TextXAlignment.Left
		tlTitle.BackgroundTransparency = 1

		local tlDesc = Instance.new("TextLabel", teleLockCard)
		tlDesc.Text = "Unlock this exhibit's live animal telemetry to inspect individual koalas, view equipped outfits and bonus multipliers, track individual happiness, and see exact cash generated."
		tlDesc.TextColor3 = Color3.fromRGB(160, 175, 195)
		tlDesc.Font = Enum.Font.Gotham
		tlDesc.TextSize = 12
		tlDesc.TextWrapped = true
		tlDesc.Position = UDim2.new(0, 16, 0, 38)
		tlDesc.Size = UDim2.new(1, -32, 0, 36)
		tlDesc.TextXAlignment = Enum.TextXAlignment.Left
		tlDesc.BackgroundTransparency = 1

		local unlockTeleBtn = Instance.new("TextButton", teleLockCard)
		unlockTeleBtn.Text = string.format("Unlock Exhibit Telemetry ($%d Cash)", data.telemetryCost or 250)
		unlockTeleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		unlockTeleBtn.Font = Enum.Font.GothamBold
		unlockTeleBtn.TextSize = 13
		unlockTeleBtn.Size = UDim2.new(0, 300, 0, 34)
		unlockTeleBtn.Position = UDim2.new(0, 16, 0, 88)
		unlockTeleBtn.BackgroundColor3 = Color3.fromRGB(45, 120, 210)
		unlockTeleBtn.BorderSizePixel = 0

		local utCorner = Instance.new("UICorner", unlockTeleBtn)
		utCorner.CornerRadius = UDim.new(0, 6)

		unlockTeleBtn.MouseButton1Click:Connect(function()
			unlockTeleBtn.Active = false
			unlockTeleBtn.Text = "Unlocking..."
			local success, newPayload = actionRemote:InvokeServer("UnlockExhibitTelemetry", exh.name)
			if success and type(newPayload) == "table" then
				currentData = newPayload
				renderTabBar(newPayload)
				renderView(newPayload)
			else
				unlockTeleBtn.Active = true
				unlockTeleBtn.Text = string.format("Unlock Exhibit Telemetry ($%d Cash)", data.telemetryCost or 250)
			end
		end)

	else
		-- UNLOCKED KOALA TELEMETRY ROSTER
		local rosterHeader = Instance.new("TextLabel", scroll)
		rosterHeader.Text = "KOALA ROSTER TELEMETRY"
		rosterHeader.TextColor3 = Color3.fromRGB(150, 165, 185)
		rosterHeader.Font = Enum.Font.GothamBold
		rosterHeader.TextSize = 13
		rosterHeader.TextXAlignment = Enum.TextXAlignment.Left
		rosterHeader.Size = UDim2.new(1, -10, 0, 24)
		rosterHeader.BackgroundTransparency = 1
		rosterHeader.LayoutOrder = 3

		local rosterContainer = Instance.new("Frame", scroll)
		rosterContainer.Size = UDim2.new(1, -10, 0, 0)
		rosterContainer.AutomaticSize = Enum.AutomaticSize.Y
		rosterContainer.BackgroundTransparency = 1
		rosterContainer.LayoutOrder = 4

		local rList = Instance.new("UIListLayout", rosterContainer)
		rList.Padding = UDim.new(0, 6)
		rList.SortOrder = Enum.SortOrder.LayoutOrder

		if #exh.koalas == 0 then
			local emptyMsg = Instance.new("TextLabel", rosterContainer)
			emptyMsg.Text = "No koalas currently in this exhibit."
			emptyMsg.TextColor3 = Color3.fromRGB(130, 140, 155)
			emptyMsg.Font = Enum.Font.Gotham
			emptyMsg.TextSize = 13
			emptyMsg.Size = UDim2.new(1, 0, 0, 30)
			emptyMsg.BackgroundTransparency = 1
		else
			for kIndex, k in ipairs(exh.koalas) do
				local kCard = Instance.new("Frame", rosterContainer)
				kCard.Size = UDim2.new(1, 0, 0, 40)
				kCard.BackgroundColor3 = Color3.fromRGB(18, 23, 32)
				kCard.BorderSizePixel = 0
				kCard.LayoutOrder = kIndex

				local kcCorner = Instance.new("UICorner", kCard)
				kcCorner.CornerRadius = UDim.new(0, 6)

				local rarityColor = getRarityColor(k.rarity)
				local kcStroke = Instance.new("UIStroke", kCard)
				kcStroke.Color = rarityColor
				kcStroke.Transparency = (k.rarity == "Cute") and 0.85 or 0.4
				kcStroke.Thickness = 1

				-- Koala Name + Stage
				local nameLbl = Instance.new("TextLabel", kCard)
				nameLbl.Text = string.format("%s (%s)", k.name, k.stageName)
				nameLbl.TextColor3 = Color3.fromRGB(240, 245, 255)
				nameLbl.Font = Enum.Font.GothamBold
				nameLbl.TextSize = 13
				nameLbl.TextXAlignment = Enum.TextXAlignment.Left
				nameLbl.Position = UDim2.new(0, 10, 0, 0)
				nameLbl.Size = UDim2.new(0.35, 0, 1, 0)
				nameLbl.BackgroundTransparency = 1

				-- Outfits
				local outfitText = "No Outfit"
				if k.hat ~= "" and k.necklace ~= "" then
					outfitText = string.format("[Hat] %s + [Neck] %s (+Combo)", k.hat, k.necklace)
				elseif k.hat ~= "" then
					outfitText = "[Hat] " .. k.hat
				elseif k.necklace ~= "" then
					outfitText = "[Neck] " .. k.necklace
				end

				local outfitLbl = Instance.new("TextLabel", kCard)
				outfitLbl.Text = outfitText
				outfitLbl.TextColor3 = Color3.fromRGB(170, 185, 205)
				outfitLbl.Font = Enum.Font.Gotham
				outfitLbl.TextSize = 12
				outfitLbl.TextXAlignment = Enum.TextXAlignment.Left
				outfitLbl.Position = UDim2.new(0.36, 0, 0, 0)
				outfitLbl.Size = UDim2.new(0.35, 0, 1, 0)
				outfitLbl.BackgroundTransparency = 1

				-- Happiness
				local kHappyColor, _ = getHappinessColor(k.happiness)
				local happyLbl = Instance.new("TextLabel", kCard)
				local happyText = string.format("%d%%", k.happiness)
				if k.isCuddled then
					happyText = happyText .. " (Cuddled)"
				end
				happyLbl.Text = happyText
				happyLbl.TextColor3 = kHappyColor
				happyLbl.Font = Enum.Font.GothamBold
				happyLbl.TextSize = 12
				happyLbl.Position = UDim2.new(0.68, 0, 0, 0)
				happyLbl.Size = UDim2.new(0.16, 0, 1, 0)
				happyLbl.BackgroundTransparency = 1

				-- Live Cash
				local cashLbl = Instance.new("TextLabel", kCard)
				cashLbl.Text = string.format("+$%d", k.payout)
				cashLbl.TextColor3 = Color3.fromRGB(90, 230, 120)
				cashLbl.Font = Enum.Font.GothamBold
				cashLbl.TextSize = 13
				cashLbl.TextXAlignment = Enum.TextXAlignment.Right
				cashLbl.Position = UDim2.new(0.85, 0, 0, 0)
				cashLbl.Size = UDim2.new(0.13, -10, 1, 0)
				cashLbl.BackgroundTransparency = 1
			end
		end
	end
end

-- Switches and renders the active view
function renderView(data)
	if not data then return end
	currentData = data

	if not data.isTerminalUnlocked then
		renderLockedScreen(data)
	else
		if activeTab == "Overview" then
			renderOverviewTab(data)
		else
			renderExhibitTab(data, activeTab)
		end
	end
end

-- Open/Close Transitions
local function showDashboard()
	createGui()
	isOpen = true
	screenGui.Enabled = true

	mainFrame.Position = UDim2.new(0.5, -360, 0.5, -250)
	mainFrame.BackgroundTransparency = 1
	overlay.BackgroundTransparency = 1

	tween(overlay, 0.25, { BackgroundTransparency = 0.55 })
	tween(mainFrame, 0.3, { Position = UDim2.new(0.5, -360, 0.5, -280), BackgroundTransparency = 0.05 }, Enum.EasingStyle.Back)

	-- Fetch Initial Payload
	local data = getDataRemote:InvokeServer()
	currentData = data
	renderTabBar(data)
	renderView(data)

	-- Live polling while open
	if refreshThread then task.cancel(refreshThread) end
	refreshThread = task.spawn(function()
		while isOpen do
			task.wait(4)
			if isOpen and currentData and currentData.isTerminalUnlocked then
				local freshData = getDataRemote:InvokeServer()
				if isOpen and freshData then
					currentData = freshData
					renderView(freshData)
				end
			end
		end
	end)
end

function hideDashboard()
	if not isOpen then return end
	isOpen = false
	closeRenameModal()

	if refreshThread then
		task.cancel(refreshThread)
		refreshThread = nil
	end

	tween(overlay, 0.2, { BackgroundTransparency = 1 })
	local anim = tween(mainFrame, 0.2, { Position = UDim2.new(0.5, -360, 0.5, -250), BackgroundTransparency = 1 })
	anim.Completed:Connect(function()
		if not isOpen and screenGui then
			screenGui.Enabled = false
		end
	end)
end

-- Hook remote trigger from Zookeeper Computer
openRemote.OnClientEvent:Connect(function()
	if isOpen then
		hideDashboard()
	else
		showDashboard()
	end
end)

print("[ZooAnalyticsController] Initialized with Clean ASCII UI, Separate Diagnostics Unlock, and Modal Rename.")
