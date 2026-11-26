local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Net = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net"))
local openDeskRemote = Net.Remote("OpenStaffDesk")
local staffActionRemote = Net.Remote("StaffAction")

local COLORS = {
	Bg = Color3.fromRGB(18, 24, 34),
	Card = Color3.fromRGB(26, 34, 48),
	Stroke = Color3.fromRGB(50, 65, 90),
	Text = Color3.fromRGB(240, 245, 255),
	Muted = Color3.fromRGB(155, 170, 190),
	Accent = Color3.fromRGB(80, 215, 130),
	Warn = Color3.fromRGB(245, 185, 70),
	Danger = Color3.fromRGB(235, 95, 95),
	BtnDisabled = Color3.fromRGB(55, 62, 75),
}

local screenGui = nil
local currentRoleId = "Feeder"
local isLoading = false

local function addCorner(inst, r)
	local c = Instance.new("UICorner", inst)
	c.CornerRadius = UDim.new(0, r or 10)
	return c
end

local function addStroke(inst, color, thickness)
	local s = Instance.new("UIStroke", inst)
	s.Color = color or COLORS.Stroke
	s.Thickness = thickness or 1
	return s
end

local function closeUI()
	if screenGui then
		screenGui:Destroy()
		screenGui = nil
	end
end

local function renderUI(state)
	closeUI()
	if not state then return end

	screenGui = Instance.new("ScreenGui")
	screenGui.Name = "StaffDeskGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local backdrop = Instance.new("Frame", screenGui)
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	backdrop.BackgroundTransparency = 0.45
	backdrop.BorderSizePixel = 0

	local panel = Instance.new("Frame", backdrop)
	panel.Size = UDim2.new(0, 480, 0, 480)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.BackgroundColor3 = COLORS.Bg
	panel.BorderSizePixel = 0
	addCorner(panel, 14)
	addStroke(panel, COLORS.Stroke, 1.5)

	-- Header
	local title = Instance.new("TextLabel", panel)
	title.Text = "👷  Staff Manager"
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = COLORS.Text
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Size = UDim2.new(1, -60, 0, 32)
	title.Position = UDim2.new(0, 20, 0, 14)
	title.BackgroundTransparency = 1

	local closeBtn = Instance.new("TextButton", panel)
	closeBtn.Text = "X"
	closeBtn.Font = Enum.Font.GothamBold
	closeBtn.TextSize = 16
	closeBtn.TextColor3 = COLORS.Muted
	closeBtn.Size = UDim2.new(0, 32, 0, 32)
	closeBtn.Position = UDim2.new(1, -46, 0, 14)
	closeBtn.BackgroundColor3 = COLORS.Card
	closeBtn.BorderSizePixel = 0
	addCorner(closeBtn, 8)
	closeBtn.MouseButton1Click:Connect(closeUI)

	-- Role Tabs
	local roles = state.availableRoles or {}
	local tabBar = Instance.new("Frame", panel)
	tabBar.Size = UDim2.new(1, -40, 0, 34)
	tabBar.Position = UDim2.new(0, 20, 0, 52)
	tabBar.BackgroundTransparency = 1

	local tabLayout = Instance.new("UIListLayout", tabBar)
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder

	local tabCount = math.max(#roles, 1)
	local tabWidthScale = 1 / tabCount
	for idx, r in ipairs(roles) do
		local isSelected = (r.id == state.roleId)
		local tabBtn = Instance.new("TextButton", tabBar)
		tabBtn.LayoutOrder = idx
		tabBtn.Size = UDim2.new(tabWidthScale, -6, 1, 0)
		tabBtn.BackgroundColor3 = isSelected and COLORS.Accent or COLORS.Card
		tabBtn.TextColor3 = isSelected and Color3.fromRGB(15, 22, 18) or COLORS.Text
		tabBtn.Font = Enum.Font.GothamBold
		tabBtn.TextSize = 12
		tabBtn.Text = string.format("%s %s", r.icon or "", r.title or r.id)
		tabBtn.TextTruncate = Enum.TextTruncate.AtEnd
		tabBtn.BorderSizePixel = 0
		addCorner(tabBtn, 8)
		if not isSelected then
			addStroke(tabBtn, COLORS.Stroke, 1)
		end

		tabBtn.MouseButton1Click:Connect(function()
			if isLoading or isSelected then return end
			isLoading = true
			currentRoleId = r.id
			local ok, nextState = staffActionRemote:InvokeServer("GetState", r.id)
			isLoading = false
			if ok and nextState then
				renderUI(nextState)
			end
		end)
	end

	local roleTitle = Instance.new("TextLabel", panel)
	roleTitle.Text = string.format("%s  %s", state.icon or "👷", state.title or "Helper")
	roleTitle.Font = Enum.Font.GothamBold
	roleTitle.TextSize = 16
	roleTitle.TextColor3 = COLORS.Text
	roleTitle.TextXAlignment = Enum.TextXAlignment.Left
	roleTitle.Size = UDim2.new(1, -40, 0, 22)
	roleTitle.Position = UDim2.new(0, 20, 0, 96)
	roleTitle.BackgroundTransparency = 1

	local desc = Instance.new("TextLabel", panel)
	desc.Text = state.description or ""
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 13
	desc.TextColor3 = COLORS.Muted
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextWrapped = true
	desc.Size = UDim2.new(1, -40, 0, 34)
	desc.Position = UDim2.new(0, 20, 0, 120)
	desc.BackgroundTransparency = 1

	-- Stats Card
	local statsCard = Instance.new("Frame", panel)
	statsCard.Size = UDim2.new(1, -40, 0, 64)
	statsCard.Position = UDim2.new(0, 20, 0, 160)
	statsCard.BackgroundColor3 = COLORS.Card
	statsCard.BorderSizePixel = 0
	addCorner(statsCard, 10)
	addStroke(statsCard, COLORS.Stroke, 1)

	local statsLbl = Instance.new("TextLabel", statsCard)
	statsLbl.Text = string.format(
		"Capacity: Up to %d Exhibits   |   Upkeep: $%d / %ds\n%s",
		state.maxExhibits or 2,
		state.upkeepCost or 150,
		state.upkeepInterval or 60,
		state.summaryLine or "Works covered exhibits automatically."
	)
	statsLbl.Font = Enum.Font.GothamMedium
	statsLbl.TextSize = 13
	statsLbl.TextColor3 = COLORS.Text
	statsLbl.TextWrapped = true
	statsLbl.TextXAlignment = Enum.TextXAlignment.Left
	statsLbl.Size = UDim2.new(1, -24, 1, -12)
	statsLbl.Position = UDim2.new(0, 12, 0, 6)
	statsLbl.BackgroundTransparency = 1

	-- Middle Card: Requirements (if not hired) OR Status/Coverage (if hired)
	local midCard = Instance.new("Frame", panel)
	midCard.Size = UDim2.new(1, -40, 0, 148)
	midCard.Position = UDim2.new(0, 20, 0, 234)
	midCard.BackgroundColor3 = COLORS.Card
	midCard.BorderSizePixel = 0
	addCorner(midCard, 10)
	addStroke(midCard, COLORS.Stroke, 1)

	local midTitle = Instance.new("TextLabel", midCard)
	midTitle.Font = Enum.Font.GothamBold
	midTitle.TextSize = 13
	midTitle.TextColor3 = COLORS.Muted
	midTitle.TextXAlignment = Enum.TextXAlignment.Left
	midTitle.Size = UDim2.new(1, -24, 0, 24)
	midTitle.Position = UDim2.new(0, 12, 0, 10)
	midTitle.BackgroundTransparency = 1

	local midBody = Instance.new("TextLabel", midCard)
	midBody.Font = Enum.Font.GothamMedium
	midBody.TextSize = 14
	midBody.TextXAlignment = Enum.TextXAlignment.Left
	midBody.TextYAlignment = Enum.TextYAlignment.Top
	midBody.TextWrapped = true
	midBody.Size = UDim2.new(1, -24, 1, -42)
	midBody.Position = UDim2.new(0, 12, 0, 36)
	midBody.BackgroundTransparency = 1

	local errorLbl = Instance.new("TextLabel", panel)
	errorLbl.Text = ""
	errorLbl.Font = Enum.Font.GothamMedium
	errorLbl.TextSize = 12
	errorLbl.TextColor3 = COLORS.Danger
	errorLbl.Size = UDim2.new(1, -40, 0, 20)
	errorLbl.Position = UDim2.new(0, 20, 1, -86)
	errorLbl.BackgroundTransparency = 1

	local actionBtn = Instance.new("TextButton", panel)
	actionBtn.Font = Enum.Font.GothamBold
	actionBtn.TextSize = 15
	actionBtn.TextColor3 = Color3.fromRGB(15, 22, 18)
	actionBtn.Size = UDim2.new(1, -40, 0, 44)
	actionBtn.Position = UDim2.new(0, 20, 1, -60)
	actionBtn.BorderSizePixel = 0
	addCorner(actionBtn, 10)

	if state.comingSoon then
		midTitle.Text = "PREVIEW"
		midBody.Text = "🚧 Coming Soon!\n\nThis helper is being prepped and will be available to hire in a future update."
		midBody.TextColor3 = COLORS.Warn

		actionBtn.Text = "Coming Soon"
		actionBtn.BackgroundColor3 = COLORS.BtnDisabled
		actionBtn.TextColor3 = COLORS.Muted
	elseif not state.isHired then
		midTitle.Text = "HIRING REQUIREMENTS"
		local req = state.requirements or {}
		local lines = {}

		if req.minManualRefills then
			local refillsOk = (req.manualRefills or 0) >= req.minManualRefills
			table.insert(lines, string.format("%s  Manual Feedings: %d / %d", refillsOk and "✅" or "❌", req.manualRefills or 0, req.minManualRefills))
		end
		if req.minManualCleanups then
			local cleanupsOk = (req.manualCleanups or 0) >= req.minManualCleanups
			table.insert(lines, string.format("%s  Manual Cleanups: %d / %d", cleanupsOk and "✅" or "❌", req.manualCleanups or 0, req.minManualCleanups))
		end
		if req.requireSecondExhibit then
			table.insert(lines, string.format("%s  Second Exhibit Repaired", req.secondExhibitRepaired and "✅" or "❌"))
		end

		local cashOk = (state.cash or 0) >= state.hireCost
		table.insert(lines, string.format("%s  Hire Fee: $%d  (You have: $%d)", cashOk and "✅" or "❌", state.hireCost, state.cash or 0))

		midBody.Text = table.concat(lines, "\n\n")
		midBody.TextColor3 = COLORS.Text

		local canHire = req.meetsWork and cashOk
		actionBtn.Text = string.format("Hire %s ($%d)", state.title, state.hireCost)
		actionBtn.BackgroundColor3 = canHire and COLORS.Accent or COLORS.BtnDisabled
		actionBtn.TextColor3 = canHire and Color3.fromRGB(15, 22, 18) or COLORS.Muted

		actionBtn.MouseButton1Click:Connect(function()
			if isLoading or not canHire then return end
			isLoading = true
			local ok, result = staffActionRemote:InvokeServer("Hire", currentRoleId)
			isLoading = false
			if ok then
				renderUI(result)
			else
				errorLbl.Text = tostring(result or "Could not hire.")
			end
		end)
	else
		midTitle.Text = "WORKER STATUS & COVERAGE"
		local statusText = state.isPaused and "⏸️ PAUSED (No upkeep charged)" or "✅ ACTIVE (On duty)"
		local coveredList = (#state.coveredExhibits > 0) and table.concat(state.coveredExhibits, ", ") or "No repaired exhibits yet"
		midBody.Text = string.format("Status: %s\n\nCovered Exhibits (%d/%d):\n%s",
			statusText,
			#state.coveredExhibits,
			state.maxExhibits or 2,
			coveredList
		)
		midBody.TextColor3 = state.isPaused and COLORS.Warn or COLORS.Accent

		actionBtn.Text = state.isPaused and "Resume Worker" or "Pause Worker (Stop Upkeep)"
		actionBtn.BackgroundColor3 = state.isPaused and COLORS.Accent or COLORS.Warn
		actionBtn.TextColor3 = Color3.fromRGB(15, 22, 18)

		actionBtn.MouseButton1Click:Connect(function()
			if isLoading then return end
			isLoading = true
			local ok, result = staffActionRemote:InvokeServer("TogglePause", currentRoleId)
			isLoading = false
			if ok then
				renderUI(result)
			else
				errorLbl.Text = tostring(result or "Action failed.")
			end
		end)
	end
end

openDeskRemote.OnClientEvent:Connect(function(roleId)
	currentRoleId = roleId or "Feeder"
	local ok, state = staffActionRemote:InvokeServer("GetState", currentRoleId)
	if ok and state then
		renderUI(state)
	end
end)
