local Theme = require(script.Parent:WaitForChild("Theme"))

local ExhibitView = {}

local function renderDiagnosticsCard(scroll, exh)
	local diagCard = Instance.new("Frame", scroll)
	diagCard.Size = UDim2.new(1, -10, 0, 172)
	diagCard.BackgroundColor3 = Color3.fromRGB(22, 28, 38)
	diagCard.BorderSizePixel = 0
	diagCard.LayoutOrder = 2
	Theme.addCorner(diagCard, 10)
	Theme.addStroke(diagCard, Color3.fromRGB(50, 70, 95), 1)

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
		socialScore = 8, socialMax = 15, totalHappiness = 50,
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

	local cuddleTip
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

	local wasteCount = bd.wasteCount or 0
	local penalty = bd.cleanlinessPenalty or 0
	local cleanRow = Instance.new("Frame", diagCard)
	cleanRow.Size = UDim2.new(1, -28, 0, 28)
	cleanRow.Position = UDim2.new(0, 14, 0, 128)
	cleanRow.BackgroundTransparency = 1

	local cleanTitle = Instance.new("TextLabel", cleanRow)
	cleanTitle.Font = Enum.Font.GothamBold
	cleanTitle.TextSize = 12
	cleanTitle.Size = UDim2.new(0.36, 0, 1, 0)
	cleanTitle.TextXAlignment = Enum.TextXAlignment.Left
	cleanTitle.BackgroundTransparency = 1

	local cleanTip = Instance.new("TextLabel", cleanRow)
	cleanTip.TextColor3 = Color3.fromRGB(170, 185, 205)
	cleanTip.Font = Enum.Font.Gotham
	cleanTip.TextSize = 12
	cleanTip.Position = UDim2.new(0.38, 0, 0, 0)
	cleanTip.Size = UDim2.new(0.62, 0, 1, 0)
	cleanTip.TextXAlignment = Enum.TextXAlignment.Left
	cleanTip.BackgroundTransparency = 1

	if penalty > 0 then
		cleanTitle.Text = string.format("Cleanliness: -%d pts", penalty)
		cleanTitle.TextColor3 = (penalty >= 30) and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(240, 180, 60)
		cleanTip.Text = string.format("- %d waste piles! Equip your Garden Shovel to clean up.", wasteCount)
	elseif wasteCount > 0 then
		cleanTitle.Text = "Cleanliness: 0 penalty"
		cleanTitle.TextColor3 = Color3.fromRGB(120, 200, 255)
		cleanTip.Text = string.format("- %d small waste pile (tolerated, shovel soon!).", wasteCount)
	else
		cleanTitle.Text = "Cleanliness: Spotless"
		cleanTitle.TextColor3 = Color3.fromRGB(90, 220, 120)
		cleanTip.Text = "- Exhibit is clean and fresh!"
	end
end

local function renderTelemetryRoster(scroll, exh)
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
		return
	end

	for kIndex, k in ipairs(exh.koalas) do
		local kCard = Instance.new("Frame", rosterContainer)
		kCard.Size = UDim2.new(1, 0, 0, 40)
		kCard.BackgroundColor3 = Color3.fromRGB(18, 23, 32)
		kCard.BorderSizePixel = 0
		kCard.LayoutOrder = kIndex
		Theme.addCorner(kCard, 6)

		local rarityColor = Theme.getRarityColor(k.rarity)
		Theme.addStroke(kCard, rarityColor, 1, (k.rarity == "Cute") and 0.85 or 0.4)

		local nameLbl = Instance.new("TextLabel", kCard)
		nameLbl.Text = string.format("%s (%s)", k.name, k.stageName)
		nameLbl.TextColor3 = Color3.fromRGB(240, 245, 255)
		nameLbl.Font = Enum.Font.GothamBold
		nameLbl.TextSize = 13
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.Position = UDim2.new(0, 10, 0, 0)
		nameLbl.Size = UDim2.new(0.35, 0, 1, 0)
		nameLbl.BackgroundTransparency = 1

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

		local kHappyColor = Theme.getHappinessColor(k.happiness)
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

function ExhibitView.render(contentContainer, data, exhibitName, callbacks)
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

	local topBar = Instance.new("Frame", contentContainer)
	topBar.Size = UDim2.new(1, 0, 0, 48)
	topBar.BackgroundColor3 = Color3.fromRGB(25, 32, 44)
	topBar.BorderSizePixel = 0
	Theme.addCorner(topBar, 10)

	local titleLbl = Instance.new("TextLabel", topBar)
	titleLbl.Text = exh.displayName
	titleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 16
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Position = UDim2.new(0, 16, 0, 0)
	titleLbl.Size = UDim2.new(1, -130, 1, 0)
	titleLbl.BackgroundTransparency = 1

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
	Theme.addCorner(renameBtn, 6)

	renameBtn.MouseButton1Click:Connect(function()
		callbacks.onRename(exh)
	end)

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

	local ribbon = Instance.new("Frame", scroll)
	ribbon.Size = UDim2.new(1, -10, 0, 48)
	ribbon.BackgroundColor3 = Color3.fromRGB(24, 30, 42)
	ribbon.BorderSizePixel = 0
	ribbon.LayoutOrder = 1
	Theme.addCorner(ribbon, 8)

	local foodPct = math.floor((exh.foodLevel / math.max(exh.maxFoodLevel, 1)) * 100)
	local _, happyMood = Theme.getHappinessColor(exh.averageHappiness)

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

	if not exh.isDiagnosticsUnlocked then
		local btnLabel = string.format("Unlock Happiness Diagnostics ($%d Cash)", data.diagnosticsCost or 200)
		Theme.createLockCard(
			scroll, 2,
			"Happiness Diagnostics [Locked]",
			"Unlock diagnostic telemetry to uncover why animal happiness isn't higher, with detailed scoring and actionable tips on food supply, cuddle care, and social bonuses.",
			btnLabel,
			function(btn)
				btn.Active = false
				btn.Text = "Unlocking..."
				if not callbacks.onUnlock("UnlockExhibitDiagnostics", exh.name) then
					btn.Active = true
					btn.Text = btnLabel
				end
			end
		)
	else
		renderDiagnosticsCard(scroll, exh)
	end

	if not exh.isTelemetryUnlocked then
		local btnLabel = string.format("Unlock Exhibit Telemetry ($%d Cash)", data.telemetryCost or 250)
		Theme.createLockCard(
			scroll, 3,
			"Koala Roster Telemetry [Locked]",
			"Unlock this exhibit's live animal telemetry to inspect individual koalas, view equipped outfits and bonus multipliers, track individual happiness, and see exact cash generated.",
			btnLabel,
			function(btn)
				btn.Active = false
				btn.Text = "Unlocking..."
				if not callbacks.onUnlock("UnlockExhibitTelemetry", exh.name) then
					btn.Active = true
					btn.Text = btnLabel
				end
			end
		)
	else
		renderTelemetryRoster(scroll, exh)
	end
end

return ExhibitView
