-- ZooAnalyticsController.client.lua
-- Client-side controller that orchestrates the Tabbed Zoo Analytics Dashboard.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))
local UI = script.Parent:WaitForChild("ZooAnalytics")
local Theme = require(UI:WaitForChild("Theme"))
local RenameModal = require(UI:WaitForChild("RenameModal"))
local OverviewView = require(UI:WaitForChild("OverviewView"))
local ExhibitView = require(UI:WaitForChild("ExhibitView"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Remotes
local openRemote = Net.Remote("OpenZooAnalytics")
local getDataRemote = Net.Remote("GetZooAnalyticsData")
local actionRemote = Net.Remote("ZooTerminalAction")
local renameRemote = Net.Remote("RenameExhibit")

-- State
local screenGui
local mainFrame
local overlay
local tabBarContainer
local contentContainer
local isOpen = false
local currentData = nil
local activeTab = "Overview" -- "Overview" or exhibitName
local refreshThread = nil

local renderView
local renderTabBar

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

local function hideDashboard()
	if not isOpen then return end
	isOpen = false
	RenameModal.close()

	if refreshThread then
		task.cancel(refreshThread)
		refreshThread = nil
	end

	Theme.tween(overlay, 0.2, { BackgroundTransparency = 1 })
	local anim = Theme.tween(mainFrame, 0.2, { Position = UDim2.new(0.5, -360, 0.5, -250), BackgroundTransparency = 1 })
	anim.Completed:Connect(function()
		if not isOpen and screenGui then
			screenGui.Enabled = false
		end
	end)
end

local function createGui()
	if screenGui then return end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ZooAnalyticsGui"
	screenGui.ResetOnSpawn = false
	screenGui.Enabled = false
	screenGui.DisplayOrder = 15
	screenGui.Parent = playerGui

	overlay = Instance.new("TextButton")
	overlay.Name = "Overlay"
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.fromRGB(8, 10, 15)
	overlay.BackgroundTransparency = 1
	overlay.Text = ""
	overlay.BorderSizePixel = 0
	overlay.Parent = screenGui

	mainFrame = Instance.new("Frame")
	mainFrame.Name = "TerminalWindow"
	mainFrame.Size = UDim2.new(0, 720, 0, 560)
	mainFrame.Position = UDim2.new(0.5, -360, 0.5, -280)
	mainFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	mainFrame.BackgroundTransparency = 0.05
	mainFrame.BorderSizePixel = 0
	mainFrame.ClipsDescendants = true
	mainFrame.Parent = screenGui
	Theme.addCorner(mainFrame, 14)
	Theme.addStroke(mainFrame, Color3.fromRGB(50, 70, 95), 1.5)

	local header = Instance.new("Frame", mainFrame)
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 52)
	header.BackgroundColor3 = Color3.fromRGB(26, 32, 44)
	header.BorderSizePixel = 0
	Theme.addCorner(header, 14)

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
	Theme.addCorner(closeBtn, 8)

	closeBtn.MouseButton1Click:Connect(hideDashboard)
	overlay.MouseButton1Click:Connect(hideDashboard)

	tabBarContainer = Instance.new("Frame", mainFrame)
	tabBarContainer.Name = "TabBar"
	tabBarContainer.Size = UDim2.new(1, -40, 0, 36)
	tabBarContainer.Position = UDim2.new(0, 20, 0, 58)
	tabBarContainer.BackgroundTransparency = 1

	local tabLayout = Instance.new("UIListLayout", tabBarContainer)
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder

	contentContainer = Instance.new("Frame", mainFrame)
	contentContainer.Name = "Content"
	contentContainer.Size = UDim2.new(1, -40, 1, -106)
	contentContainer.Position = UDim2.new(0, 20, 0, 98)
	contentContainer.BackgroundTransparency = 1
end

local function selectTab(tabKey)
	activeTab = tabKey
	RenameModal.close()
	renderTabBar(currentData)
	renderView(currentData)
end

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
		Theme.addCorner(btn, 8)

		local isActive = (activeTab == tabKey)
		if isActive then
			btn.BackgroundColor3 = Color3.fromRGB(40, 70, 110)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			Theme.addStroke(btn, Color3.fromRGB(70, 140, 230), 1)
		else
			btn.BackgroundColor3 = Color3.fromRGB(26, 32, 44)
			btn.TextColor3 = Color3.fromRGB(160, 175, 195)
			Theme.addStroke(btn, Color3.fromRGB(40, 50, 70), 1)
		end

		btn.Text = isLocked and (labelText .. " [Locked]") or labelText
		btn.MouseButton1Click:Connect(function()
			selectTab(tabKey)
		end)
	end

	createTabBtn(1, "Overview", "Overview", false)
	for i, exh in ipairs(data.exhibits) do
		local isLocked = (not exh.isTelemetryUnlocked) and (not exh.isDiagnosticsUnlocked)
		createTabBtn(i + 1, exh.name, exh.displayName, isLocked)
	end
end

local function renderLockedScreen(data)
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
	Theme.addCorner(unlockBtn, 10)

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

local exhibitCallbacks = {
	onRename = function(exh)
		RenameModal.open(mainFrame, exh, function(targetExh, newName)
			renameRemote:FireServer(targetExh.exhibitPath, newName)
			targetExh.displayName = newName
			renderTabBar(currentData)
			renderView(currentData)
		end)
	end,
	onUnlock = function(actionName, exhibitName)
		local success, newPayload = actionRemote:InvokeServer(actionName, exhibitName)
		if success and type(newPayload) == "table" then
			currentData = newPayload
			renderTabBar(newPayload)
			renderView(newPayload)
			return true
		end
		return false
	end,
}

function renderView(data)
	if not data then return end
	currentData = data
	clearContent()

	if not data.isTerminalUnlocked then
		renderLockedScreen(data)
	elseif activeTab == "Overview" then
		OverviewView.render(contentContainer, data, selectTab)
	else
		ExhibitView.render(contentContainer, data, activeTab, exhibitCallbacks)
	end
end

local function showDashboard()
	createGui()
	isOpen = true
	screenGui.Enabled = true

	mainFrame.Position = UDim2.new(0.5, -360, 0.5, -250)
	mainFrame.BackgroundTransparency = 1
	overlay.BackgroundTransparency = 1

	Theme.tween(overlay, 0.25, { BackgroundTransparency = 0.55 })
	Theme.tween(mainFrame, 0.3, { Position = UDim2.new(0.5, -360, 0.5, -280), BackgroundTransparency = 0.05 }, Enum.EasingStyle.Back)

	local data = getDataRemote:InvokeServer()
	currentData = data
	renderTabBar(data)
	renderView(data)

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

openRemote.OnClientEvent:Connect(function()
	if isOpen then
		hideDashboard()
	else
		showDashboard()
	end
end)

print("[ZooAnalyticsController] Initialized with Clean ASCII UI, Separate Diagnostics Unlock, and Modal Rename.")
