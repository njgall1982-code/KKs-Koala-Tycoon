local Theme = require(script.Parent:WaitForChild("Theme"))

local OverviewView = {}

local function createMetricCard(parent, order, titleText, valueText, subText, valueColor)
	local card = Instance.new("Frame", parent)
	card.Size = UDim2.new(0.315, 0, 1, 0)
	card.BackgroundColor3 = Color3.fromRGB(28, 35, 48)
	card.BorderSizePixel = 0
	card.LayoutOrder = order
	Theme.addCorner(card, 10)
	Theme.addStroke(card, Color3.fromRGB(45, 58, 78), 1)

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

function OverviewView.render(contentContainer, data, onSelectTab)
	local metricsRow = Instance.new("Frame", contentContainer)
	metricsRow.Name = "MetricsRow"
	metricsRow.Size = UDim2.new(1, 0, 0, 92)
	metricsRow.BackgroundTransparency = 1

	local rowLayout = Instance.new("UIListLayout", metricsRow)
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowLayout.Padding = UDim.new(0, 12)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder

	createMetricCard(metricsRow, 1, "TOTAL CASH FLOW", string.format("+$%d / 5s", data.totalRevenueRate or 0), string.format("~$%d / min", data.totalRevenuePerMin or 0), Color3.fromRGB(90, 230, 120))
	local happyColor, happyMood = Theme.getHappinessColor(data.averageHappiness or 100)
	createMetricCard(metricsRow, 2, "PARK HAPPINESS", string.format("%d%%", data.averageHappiness or 100), happyMood, happyColor)
	createMetricCard(metricsRow, 3, "KOALA POPULATION", string.format("%d Koalas", data.totalKoalas or 0), string.format("Across %d Exhibits", #data.exhibits), Color3.fromRGB(100, 200, 255))

	local sectionLbl = Instance.new("TextLabel", contentContainer)
	sectionLbl.Text = "EXHIBIT ROSTER & STATUS"
	sectionLbl.TextColor3 = Color3.fromRGB(150, 165, 185)
	sectionLbl.Font = Enum.Font.GothamBold
	sectionLbl.TextSize = 13
	sectionLbl.TextXAlignment = Enum.TextXAlignment.Left
	sectionLbl.Size = UDim2.new(1, 0, 0, 24)
	sectionLbl.Position = UDim2.new(0, 0, 0, 102)
	sectionLbl.BackgroundTransparency = 1

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
		Theme.addCorner(card, 10)
		Theme.addStroke(card, Color3.fromRGB(45, 58, 80), 1)

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

		local subText = Instance.new("TextLabel", card)
		subText.Text = string.format("Food: %d%%  |  Koalas: %d/%d  |  Happiness: %d%%  |  +$%d/5s", foodPct, exh.koalaCount, exh.maxKoalas, exh.averageHappiness, exh.revenue)
		subText.TextColor3 = Color3.fromRGB(160, 175, 195)
		subText.Font = Enum.Font.GothamMedium
		subText.TextSize = 12
		subText.TextXAlignment = Enum.TextXAlignment.Left
		subText.Position = UDim2.new(0, 14, 0, 36)
		subText.Size = UDim2.new(0.65, 0, 0, 20)
		subText.BackgroundTransparency = 1

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
		Theme.addCorner(jumpBtn, 6)

		jumpBtn.MouseButton1Click:Connect(function()
			onSelectTab(exh.name)
		end)
	end
end

return OverviewView
