local TweenService = game:GetService("TweenService")

local Theme = {}

function Theme.tween(instance, duration, properties, easingStyle)
	local info = TweenInfo.new(duration or 0.25, easingStyle or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local anim = TweenService:Create(instance, info, properties)
	anim:Play()
	return anim
end

function Theme.getHappinessColor(score)
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

function Theme.getRarityColor(rarity)
	if rarity == "Ultra Cute" then
		return Color3.fromRGB(220, 60, 255)
	elseif rarity == "Extra Cute" then
		return Color3.fromRGB(255, 200, 30)
	else
		return Color3.fromRGB(180, 180, 180)
	end
end

function Theme.addCorner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
	return c
end

function Theme.addStroke(parent, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color or Color3.fromRGB(50, 70, 95)
	s.Thickness = thickness or 1
	if transparency then
		s.Transparency = transparency
	end
	s.Parent = parent
	return s
end

function Theme.createLockCard(parent, layoutOrder, titleText, descText, buttonText, onUnlock)
	local card = Instance.new("Frame", parent)
	card.Size = UDim2.new(1, -10, 0, 140)
	card.BackgroundColor3 = Color3.fromRGB(22, 28, 38)
	card.BorderSizePixel = 0
	card.LayoutOrder = layoutOrder
	Theme.addCorner(card, 10)
	Theme.addStroke(card, Color3.fromRGB(50, 70, 95), 1)

	local title = Instance.new("TextLabel", card)
	title.Text = titleText
	title.TextColor3 = Color3.fromRGB(240, 245, 255)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 15
	title.Position = UDim2.new(0, 16, 0, 14)
	title.Size = UDim2.new(1, -32, 0, 22)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.BackgroundTransparency = 1

	local desc = Instance.new("TextLabel", card)
	desc.Text = descText
	desc.TextColor3 = Color3.fromRGB(160, 175, 195)
	desc.Font = Enum.Font.Gotham
	desc.TextSize = 12
	desc.TextWrapped = true
	desc.Position = UDim2.new(0, 16, 0, 38)
	desc.Size = UDim2.new(1, -32, 0, 36)
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.BackgroundTransparency = 1

	local btn = Instance.new("TextButton", card)
	btn.Text = buttonText
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 13
	btn.Size = UDim2.new(0, 300, 0, 34)
	btn.Position = UDim2.new(0, 16, 0, 88)
	btn.BackgroundColor3 = Color3.fromRGB(45, 120, 210)
	btn.BorderSizePixel = 0
	Theme.addCorner(btn, 6)

	btn.MouseButton1Click:Connect(function()
		onUnlock(btn)
	end)

	return card
end

return Theme
