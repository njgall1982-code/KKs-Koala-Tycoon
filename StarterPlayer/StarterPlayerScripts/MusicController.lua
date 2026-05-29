-- Background Music (BGM) Controller & Audio HUD
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- Load playlist configuration
local MusicConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("MusicConfig"))
local Playlist = MusicConfig.Playlist

if #Playlist == 0 then
	warn("[MusicController] No songs found in MusicConfig!")
	return
end

-- Playback State
local queue = {}
local currentSound = nil
local soundEndedConnection = nil
local lastPlayedSongName = nil

local volume = 0.5 -- Default volume (0.0 to 1.0)
local isMuted = false
local isPaused = false
local isShuffleMode = true
local isDraggingVolume = false

-- Utility function to shuffle an array
local function shuffle(tbl)
	local size = #tbl
	for i = size, 2, -1 do
		local j = math.random(i)
		tbl[i], tbl[j] = tbl[j], tbl[i]
	end
	return tbl
end

-- Get the next song from the queue based on playback mode
local function getNextSong()
	if isShuffleMode then
		if #queue == 0 then
			-- Repopulate queue
			for i = 1, #Playlist do
				table.insert(queue, i)
			end
			shuffle(queue)
			
			-- Prevent playing the same song twice in a row when reshuffling
			if lastPlayedSongName and Playlist[queue[1]].Name == lastPlayedSongName and #queue > 1 then
				queue[1], queue[#queue] = queue[#queue], queue[1]
			end
		end
		
		local nextIndex = table.remove(queue, 1)
		local song = Playlist[nextIndex]
		lastPlayedSongName = song.Name
		return song
	else
		-- Sequential Mode
		local nextIndex = 1
		if lastPlayedSongName then
			for i, song in ipairs(Playlist) do
				if song.Name == lastPlayedSongName then
					nextIndex = i + 1
					if nextIndex > #Playlist then
						nextIndex = 1
					end
					break
				end
			end
		end
		local song = Playlist[nextIndex]
		lastPlayedSongName = song.Name
		return song
	end
end

---------------------------------------------------------
-- UI Construction (Programmatic & Glassmorphic)
---------------------------------------------------------

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MusicHUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 260, 0, 80)
mainFrame.Position = UDim2.new(0, 20, 1, -100) -- Float at bottom left
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
mainFrame.BackgroundTransparency = 0.25
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 12)
uiCorner.Parent = mainFrame

local uiStroke = Instance.new("UIStroke")
uiStroke.Color = Color3.fromRGB(255, 255, 255)
uiStroke.Thickness = 1
uiStroke.Transparency = 0.8
uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
uiStroke.Parent = mainFrame

-- Title Text (Scrolling Marquee)
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "TitleLabel"
titleLabel.Size = UDim2.new(1, -44, 0, 20) -- Width adjusted to leave space for minimize button
titleLabel.Position = UDim2.new(0, 12, 0, 10)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Loading playlist..."
titleLabel.TextColor3 = Color3.fromRGB(240, 240, 245)
titleLabel.TextSize = 13
titleLabel.Font = Enum.Font.GothamMedium
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ClipsDescendants = true
titleLabel.Parent = mainFrame

-- Text Marquee Scroller for long song titles
local marqueeThread = nil
local function startMarquee(songName)
	if marqueeThread then
		task.cancel(marqueeThread)
	end
	
	local baseText = "Now Playing: " .. songName
	if string.len(baseText) <= 26 then
		titleLabel.Text = baseText
		return
	end
	
	marqueeThread = task.spawn(function()
		local scrollText = baseText .. "      •      "
		while true do
			titleLabel.Text = scrollText
			task.wait(0.25)
			scrollText = string.sub(scrollText, 2) .. string.sub(scrollText, 1, 1)
		end
	end)
end

-- Helper to add subtle border stroke to buttons
local function addSubtleStroke(instance)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 1
	stroke.Transparency = 0.9
	stroke.Parent = instance
end

-- Helper for hover transitions
local function setupButtonHover(button)
	local originalColor = button.BackgroundColor3
	local hoverColor = originalColor:Lerp(Color3.fromRGB(255, 255, 255), 0.15)
	
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = hoverColor}):Play()
	end)
	button.MouseLeave:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.15), {BackgroundColor3 = originalColor}):Play()
	end)
end

-- Buttons
local playPauseBtn = Instance.new("TextButton")
playPauseBtn.Name = "PlayPause"
playPauseBtn.Size = UDim2.new(0, 32, 0, 32)
playPauseBtn.Position = UDim2.new(0, 12, 0, 38)
playPauseBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
playPauseBtn.Text = "⏸"
playPauseBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
playPauseBtn.TextSize = 14
playPauseBtn.Font = Enum.Font.GothamBold
playPauseBtn.Parent = mainFrame

local btnCorner1 = Instance.new("UICorner")
btnCorner1.CornerRadius = UDim.new(0, 8)
btnCorner1.Parent = playPauseBtn
addSubtleStroke(playPauseBtn)
setupButtonHover(playPauseBtn)

local skipBtn = Instance.new("TextButton")
skipBtn.Name = "Skip"
skipBtn.Size = UDim2.new(0, 32, 0, 32)
skipBtn.Position = UDim2.new(0, 50, 0, 38)
skipBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
skipBtn.Text = "⏭"
skipBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
skipBtn.TextSize = 14
skipBtn.Font = Enum.Font.GothamBold
skipBtn.Parent = mainFrame

local btnCorner2 = btnCorner1:Clone()
btnCorner2.Parent = skipBtn
addSubtleStroke(skipBtn)
setupButtonHover(skipBtn)

local muteBtn = Instance.new("TextButton")
muteBtn.Name = "Mute"
muteBtn.Size = UDim2.new(0, 32, 0, 32)
muteBtn.Position = UDim2.new(0, 88, 0, 38)
muteBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
muteBtn.Text = "🔊"
muteBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
muteBtn.TextSize = 14
muteBtn.Font = Enum.Font.GothamBold
muteBtn.Parent = mainFrame

local btnCorner3 = btnCorner1:Clone()
btnCorner3.Parent = muteBtn
addSubtleStroke(muteBtn)
setupButtonHover(muteBtn)

local shuffleBtn = Instance.new("TextButton")
shuffleBtn.Name = "ShuffleToggle"
shuffleBtn.Size = UDim2.new(0, 32, 0, 32)
shuffleBtn.Position = UDim2.new(0, 126, 0, 38)
shuffleBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
shuffleBtn.Text = "🔀"
shuffleBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
shuffleBtn.TextSize = 14
shuffleBtn.Font = Enum.Font.GothamBold
shuffleBtn.Parent = mainFrame

local btnCorner4 = btnCorner1:Clone()
btnCorner4.Parent = shuffleBtn
addSubtleStroke(shuffleBtn)
setupButtonHover(shuffleBtn)

-- Volume Container (Interactive click/drag region)
local volumeBar = Instance.new("TextButton")
volumeBar.Name = "VolumeBar"
volumeBar.Size = UDim2.new(0, 80, 0, 16)
volumeBar.Position = UDim2.new(0, 168, 0, 46)
volumeBar.BackgroundTransparency = 1
volumeBar.Text = ""
volumeBar.Parent = mainFrame

local volumeLineBg = Instance.new("Frame")
volumeLineBg.Name = "LineBg"
volumeLineBg.Size = UDim2.new(1, 0, 0, 4)
volumeLineBg.Position = UDim2.new(0, 0, 0.5, -2)
volumeLineBg.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
volumeLineBg.BorderSizePixel = 0
volumeLineBg.Parent = volumeBar

local lineBgCorner = Instance.new("UICorner")
lineBgCorner.CornerRadius = UDim.new(0, 2)
lineBgCorner.Parent = volumeLineBg

local volumeFill = Instance.new("Frame")
volumeFill.Name = "Fill"
volumeFill.Size = UDim2.new(volume, 0, 1, 0)
volumeFill.BackgroundColor3 = Color3.fromRGB(120, 220, 120)
volumeFill.BorderSizePixel = 0
volumeFill.Parent = volumeLineBg

local fillCorner = lineBgCorner:Clone()
fillCorner.Parent = volumeFill

local volumeHandle = Instance.new("TextButton")
volumeHandle.Name = "Handle"
volumeHandle.Size = UDim2.new(0, 10, 0, 10)
volumeHandle.Position = UDim2.new(volume, -5, 0.5, -5)
volumeHandle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
volumeHandle.BorderSizePixel = 0
volumeHandle.Text = ""
volumeHandle.Parent = volumeLineBg

local handleCorner = Instance.new("UICorner")
handleCorner.CornerRadius = UDim.new(1, 0)
handleCorner.Parent = volumeHandle

-- Minimize/Expand UI Configuration
local originalSize = UDim2.new(0, 260, 0, 80)
local originalPosition = UDim2.new(0, 20, 1, -100)

local minimizedSize = UDim2.new(0, 36, 0, 36)
local minimizedPosition = UDim2.new(0, 20, 1, -56)

-- Minimize Button
local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Name = "Minimize"
minimizeBtn.Size = UDim2.new(0, 18, 0, 18)
minimizeBtn.Position = UDim2.new(1, -28, 0, 10)
minimizeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
minimizeBtn.Text = "-"
minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeBtn.TextSize = 14
minimizeBtn.Font = Enum.Font.GothamBold
minimizeBtn.Parent = mainFrame

local minCorner = Instance.new("UICorner")
minCorner.CornerRadius = UDim.new(0, 4)
minCorner.Parent = minimizeBtn
addSubtleStroke(minimizeBtn)
setupButtonHover(minimizeBtn)

-- Expand Button
local expandBtn = Instance.new("TextButton")
expandBtn.Name = "ExpandButton"
expandBtn.Size = minimizedSize
expandBtn.Position = minimizedPosition
expandBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
expandBtn.BackgroundTransparency = 0.25
expandBtn.BorderSizePixel = 0
expandBtn.Text = "🎵"
expandBtn.TextColor3 = Color3.fromRGB(240, 240, 245)
expandBtn.TextSize = 18
expandBtn.Visible = false
expandBtn.Parent = screenGui

local expCorner = Instance.new("UICorner")
expCorner.CornerRadius = UDim.new(1, 0) -- Circle
expCorner.Parent = expandBtn
addSubtleStroke(expandBtn)
setupButtonHover(expandBtn)

-- Helper to set visibility of mainFrame contents during minimize
local function setMainFrameContentsVisible(visible)
	for _, child in ipairs(mainFrame:GetChildren()) do
		if child ~= uiCorner and child ~= uiStroke and child ~= minimizeBtn then
			if child:IsA("GuiObject") then
				child.Visible = visible
			end
		end
	end
end

-- Minimize Event
minimizeBtn.MouseButton1Click:Connect(function()
	setMainFrameContentsVisible(false)
	minimizeBtn.Visible = false
	
	local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local sizeTween = TweenService:Create(mainFrame, tweenInfo, {
		Size = minimizedSize,
		Position = minimizedPosition,
		BackgroundTransparency = 1 -- Fade out background so it merges into expandBtn
	})
	
	sizeTween:Play()
	sizeTween.Completed:Connect(function()
		mainFrame.Visible = false
		expandBtn.Visible = true
		expandBtn.Size = UDim2.new(0, 0, 0, 0)
		expandBtn.Position = minimizedPosition + UDim2.new(0, 18, 0, 18)
		
		TweenService:Create(expandBtn, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = minimizedSize,
			Position = minimizedPosition
		}):Play()
	end)
end)

-- Expand Event
expandBtn.MouseButton1Click:Connect(function()
	TweenService:Create(expandBtn, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 0, 0, 0),
		Position = minimizedPosition + UDim2.new(0, 18, 0, 18)
	}):Play()
	
	task.wait(0.15)
	expandBtn.Visible = false
	
	mainFrame.Visible = true
	mainFrame.BackgroundTransparency = 0.25
	
	local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local sizeTween = TweenService:Create(mainFrame, tweenInfo, {
		Size = originalSize,
		Position = originalPosition
	})
	
	sizeTween:Play()
	sizeTween.Completed:Connect(function()
		setMainFrameContentsVisible(true)
		minimizeBtn.Visible = true
	end)
end)

-- Parent GUI to Player
screenGui.Parent = playerGui

---------------------------------------------------------
-- Playback Logic
---------------------------------------------------------

local function playNext()
	if soundEndedConnection then
		soundEndedConnection:Disconnect()
		soundEndedConnection = nil
	end
	
	-- Reset paused status when manually skipping or playing next
	isPaused = false
	playPauseBtn.Text = "⏸"
	
	local song = getNextSong()
	
	-- Fade out current sound and destroy it
	if currentSound then
		local oldSound = currentSound
		currentSound = nil
		local fadeTween = TweenService:Create(oldSound, TweenInfo.new(0.8), {Volume = 0})
		fadeTween:Play()
		fadeTween.Completed:Connect(function()
			oldSound:Stop()
			oldSound:Destroy()
		end)
	end
	
	-- Create and setup new Sound instance client-side
	local sound = Instance.new("Sound")
	sound.SoundId = song.Id
	sound.Volume = 0
	sound.Looped = false
	sound.Parent = SoundService
	
	currentSound = sound
	sound:Play()
	
	-- Fade in
	local targetVolume = isMuted and 0 or volume
	TweenService:Create(sound, TweenInfo.new(0.8), {Volume = targetVolume}):Play()
	
	-- Start marquee text scrolling
	startMarquee(song.Name)
	
	-- Wait for sound to end to advance
	soundEndedConnection = sound.Ended:Connect(function()
		playNext()
	end)
end

---------------------------------------------------------
-- UI Interactions
---------------------------------------------------------

-- Play/Pause click
playPauseBtn.MouseButton1Click:Connect(function()
	if not currentSound then return end
	isPaused = not isPaused
	if isPaused then
		currentSound:Pause()
		playPauseBtn.Text = "▶"
	else
		currentSound:Resume()
		playPauseBtn.Text = "⏸"
	end
end)

-- Skip click
skipBtn.MouseButton1Click:Connect(function()
	playNext()
end)

-- Mute click
muteBtn.MouseButton1Click:Connect(function()
	isMuted = not isMuted
	if isMuted then
		muteBtn.Text = "🔇"
		volumeFill.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
		if currentSound then
			TweenService:Create(currentSound, TweenInfo.new(0.2), {Volume = 0}):Play()
		end
	else
		muteBtn.Text = "🔊"
		volumeFill.BackgroundColor3 = Color3.fromRGB(120, 220, 120)
		if currentSound and not isPaused then
			TweenService:Create(currentSound, TweenInfo.new(0.2), {Volume = volume}):Play()
		end
	end
end)

-- Shuffle Toggle click
shuffleBtn.MouseButton1Click:Connect(function()
	isShuffleMode = not isShuffleMode
	if isShuffleMode then
		shuffleBtn.Text = "🔀"
		table.clear(queue) -- Clear and trigger reshuffle next getNextSong
	else
		shuffleBtn.Text = "🔁"
	end
end)

-- Volume Adjustment
local function updateVolumeFromInput(inputX)
	local barAbsolutePosition = volumeLineBg.AbsolutePosition.X
	local barAbsoluteWidth = volumeLineBg.AbsoluteSize.X
	local relativeX = inputX - barAbsolutePosition
	local percentage = math.clamp(relativeX / barAbsoluteWidth, 0, 1)
	
	volume = percentage
	volumeFill.Size = UDim2.new(percentage, 0, 1, 0)
	volumeHandle.Position = UDim2.new(percentage, -5, 0.5, -5)
	
	if not isMuted and currentSound then
		currentSound.Volume = volume
	end
	
	-- Visual feedback for volume being muted or 0
	if volume == 0 or isMuted then
		volumeFill.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
	else
		volumeFill.BackgroundColor3 = Color3.fromRGB(120, 220, 120)
	end
end

volumeBar.MouseButton1Down:Connect(function()
	isDraggingVolume = true
	local mouseLocation = UserInputService:GetMouseLocation()
	updateVolumeFromInput(mouseLocation.X)
end)

volumeHandle.MouseButton1Down:Connect(function()
	isDraggingVolume = true
end)

UserInputService.InputChanged:Connect(function(input)
	if isDraggingVolume and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		updateVolumeFromInput(input.Position.X)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		isDraggingVolume = false
	end
end)

-- Start initial playback
playNext()
