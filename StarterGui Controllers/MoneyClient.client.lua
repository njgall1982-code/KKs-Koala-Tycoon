local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local screenGui = script.Parent
local mainFrame = screenGui:WaitForChild("MainFrame")
local amountLabel = mainFrame:WaitForChild("Amount")

local lastCash = nil
local cashConnection = nil

local function formatCash(value)
	return "$" .. string.format("%.0f", value):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

local function spawnCashPopup(delta)
	if delta == 0 then return end

	local isGain = delta > 0
	local popup = Instance.new("TextLabel")
	popup.Name = "CashDeltaPopup"
	popup.BackgroundTransparency = 1
	popup.Size = UDim2.new(0, mainFrame.Size.X.Offset, 0, 24)
	popup.Position = UDim2.new(
		mainFrame.Position.X.Scale,
		mainFrame.Position.X.Offset,
		mainFrame.Position.Y.Scale,
		mainFrame.Position.Y.Offset + mainFrame.Size.Y.Offset + 4
	)
	popup.Font = Enum.Font.GothamBold
	popup.TextSize = 18
	popup.TextXAlignment = Enum.TextXAlignment.Center
	popup.TextColor3 = isGain and Color3.fromRGB(90, 230, 120) or Color3.fromRGB(255, 95, 95)
	popup.Text = (isGain and "+" or "-") .. formatCash(math.abs(delta))
	popup.TextTransparency = 0
	popup.ZIndex = mainFrame.ZIndex + 1

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 1.5
	stroke.Transparency = 0.25
	stroke.Parent = popup

	popup.Parent = screenGui

	local targetPos = UDim2.new(
		popup.Position.X.Scale,
		popup.Position.X.Offset,
		popup.Position.Y.Scale,
		popup.Position.Y.Offset + 16
	)
	local tweenInfo = TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local moveTween = TweenService:Create(popup, tweenInfo, {
		Position = targetPos,
		TextTransparency = 1,
	})
	TweenService:Create(stroke, tweenInfo, { Transparency = 1 }):Play()
	moveTween:Play()
	moveTween.Completed:Connect(function()
		popup:Destroy()
	end)
end

local function updateCash(value, showDelta)
	amountLabel.Text = formatCash(value)
	if showDelta and lastCash ~= nil then
		spawnCashPopup(value - lastCash)
	end
	lastCash = value
end

local function setup()
	local leaderstats = player:WaitForChild("leaderstats", 10)
	if leaderstats then
		local cash = leaderstats:WaitForChild("Cash", 10)
		if cash then
			if cashConnection then
				cashConnection:Disconnect()
			end
			updateCash(cash.Value, false)
			cashConnection = cash.Changed:Connect(function(newValue)
				updateCash(newValue, true)
			end)
		end
	end
end

setup()
player.CharacterAdded:Connect(setup)
