local Theme = require(script.Parent:WaitForChild("Theme"))

local RenameModal = {}
local activeModal = nil

function RenameModal.close()
	if activeModal then
		activeModal:Destroy()
		activeModal = nil
	end
end

function RenameModal.open(parentFrame, exh, onSave)
	RenameModal.close()

	activeModal = Instance.new("TextButton", parentFrame)
	activeModal.Name = "RenameModalOverlay"
	activeModal.Size = UDim2.new(1, 0, 1, 0)
	activeModal.Position = UDim2.new(0, 0, 0, 0)
	activeModal.BackgroundColor3 = Color3.fromRGB(5, 8, 12)
	activeModal.BackgroundTransparency = 0.45
	activeModal.Text = ""
	activeModal.AutoButtonColor = false
	activeModal.BorderSizePixel = 0
	activeModal.ZIndex = 50

	local modalBox = Instance.new("Frame", activeModal)
	modalBox.Name = "RenameBox"
	modalBox.Size = UDim2.new(0, 420, 0, 210)
	modalBox.Position = UDim2.new(0.5, -210, 0.5, -105)
	modalBox.BackgroundColor3 = Color3.fromRGB(24, 30, 42)
	modalBox.BorderSizePixel = 0
	modalBox.ZIndex = 51
	Theme.addCorner(modalBox, 12)
	Theme.addStroke(modalBox, Color3.fromRGB(55, 75, 105), 1.5)

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
	Theme.addCorner(mClose, 6)
	mClose.MouseButton1Click:Connect(RenameModal.close)

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
	Theme.addCorner(input, 8)
	Theme.addStroke(input, Color3.fromRGB(45, 65, 92), 1)

	local inPad = Instance.new("UIPadding", input)
	inPad.PaddingLeft = UDim.new(0, 12)
	inPad.PaddingRight = UDim.new(0, 12)

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
	Theme.addCorner(cancelBtn, 8)

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
	Theme.addCorner(saveBtn, 8)

	local function doSave()
		local newName = input.Text:match("^%s*(.-)%s*$")
		if newName and newName ~= "" and exh.exhibitPath then
			RenameModal.close()
			onSave(exh, newName)
		end
	end

	cancelBtn.MouseButton1Click:Connect(RenameModal.close)
	saveBtn.MouseButton1Click:Connect(doSave)
	input.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			doSave()
		end
	end)

	input:CaptureFocus()
end

return RenameModal
