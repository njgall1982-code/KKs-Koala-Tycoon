local KoalaVFX = {}
local KoalaConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("KoalaConfig"))

-- ============================================================
-- RARITY AURA
-- ============================================

function KoalaVFX.ApplyRarityAura(koala, rarityName)
	-- Clear any existing aura first
	local existing = koala:FindFirstChild("RarityAura")
	if existing then existing:Destroy() end

	local config = nil
	for _, r in ipairs(KoalaConfig.RARITIES) do
		if r.name == rarityName then config = r break end
	end

	if not config or not config.highlightColor then return end -- "Cute" has no aura

	local auraFolder = Instance.new("Folder")
	auraFolder.Name = "RarityAura"
	auraFolder.Parent = koala

	-- Highlight glow
	local highlight = Instance.new("Highlight")
	highlight.Name = "GlowHighlight"
	highlight.FillTransparency = 0.85
	highlight.OutlineTransparency = 0.3
	highlight.FillColor = config.highlightColor
	highlight.OutlineColor = config.highlightColor
	highlight.Adornee = koala
	highlight.Parent = auraFolder

	-- Particle emitter for Ultra Cute
	if rarityName == "Ultra Cute" then
		-- Find the primary mesh part to attach particles to
		local meshPart = nil
		for _, desc in ipairs(koala:GetDescendants()) do
			if desc:IsA("MeshPart") or desc:IsA("Part") then
				meshPart = desc
				break
			end
		end

		if meshPart then
			local emitter = Instance.new("ParticleEmitter")
			emitter.Name = "HeartParticles"
			emitter.Color = ColorSequence.new(config.particleColor)
			emitter.LightEmission = 0.8
			emitter.LightInfluence = 0.2
			emitter.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.3),
				NumberSequenceKeypoint.new(1, 0),
			})
			emitter.Lifetime = NumberRange.new(1.5, 2.5)
			emitter.Rate = 4
			emitter.Speed = NumberRange.new(2, 4)
			emitter.SpreadAngle = Vector2.new(30, 30)
			emitter.RotSpeed = NumberRange.new(-45, 45)
			emitter.Rotation = NumberRange.new(0, 360)
			emitter.Parent = meshPart
		end
	end

	print("[KoalaVFX] Applied '" .. rarityName .. "' aura to " .. koala.Name)
end

-- ============================================================
-- POPUP EFFECTS
-- ============================================================

function KoalaVFX.ShowHeartEffect(target)
	local hrp = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChildOfClass("Part")
	if not hrp then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HeartPopup"
	billboard.Size = UDim2.new(2, 0, 2, 0)
	billboard.Adornee = hrp
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = target

	local label = Instance.new("TextLabel", billboard)
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "❤️"
	label.TextScaled = true

	-- Animation: float up and fade
	task.spawn(function()
		for i = 0, 20 do
			if not billboard or not label then break end
			billboard.StudsOffset = billboard.StudsOffset + Vector3.new(0, 0.1, 0)
			label.TextTransparency = i / 20
			task.wait(0.05)
		end
		if billboard then billboard:Destroy() end
	end)
end

function KoalaVFX.ShowSleepyEffect(target)
	local hrp = target:FindFirstChild("HumanoidRootPart") or target:FindFirstChildOfClass("Part")
	if not hrp then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "SleepyPopup"
	billboard.Size = UDim2.new(2, 0, 2, 0)
	billboard.Adornee = hrp
	billboard.StudsOffset = Vector3.new(1, 2, 0) -- Slightly offset to side
	billboard.AlwaysOnTop = true
	billboard.Parent = target

	local label = Instance.new("TextLabel", billboard)
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = "💤"
	label.TextScaled = true
	label.Rotation = -15

	-- Animation: float up, grow, and fade
	task.spawn(function()
		for i = 0, 30 do
			if not billboard or not label then break end
			billboard.StudsOffset = billboard.StudsOffset + Vector3.new(0.05, 0.08, 0)
			label.TextTransparency = i / 30
			label.Rotation = label.Rotation + 1
			task.wait(0.05)
		end
		if billboard then billboard:Destroy() end
	end)
end

function KoalaVFX.ShowCrateOpenEffect(position)
	local part = Instance.new("Part")
	part.Name = "CrateOpenVFX"
	part.Size = Vector3.new(1, 1, 1)
	part.Position = position
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = workspace

	-- 1. Wood splinter / dust particles
	local woodParticles = Instance.new("ParticleEmitter")
	woodParticles.Name = "WoodParticles"
	woodParticles.Color = ColorSequence.new(Color3.fromRGB(150, 110, 80))
	woodParticles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	woodParticles.Lifetime = NumberRange.new(0.5, 0.8)
	woodParticles.Rate = 0
	woodParticles.Speed = NumberRange.new(4, 8)
	woodParticles.SpreadAngle = Vector2.new(180, 180)
	woodParticles.RotSpeed = NumberRange.new(-100, 100)
	woodParticles.Parent = part

	-- 2. Star/Sparkle particles
	local sparkleParticles = Instance.new("ParticleEmitter")
	sparkleParticles.Name = "SparkleParticles"
	sparkleParticles.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0))
	sparkleParticles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparkleParticles.Lifetime = NumberRange.new(0.6, 1.0)
	sparkleParticles.Rate = 0
	sparkleParticles.Speed = NumberRange.new(3, 6)
	sparkleParticles.SpreadAngle = Vector2.new(180, 180)
	sparkleParticles.Parent = part

	-- 3. Play Satisfying Sound
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://9073146432"
	sound.Volume = 1.0
	sound.Parent = part

	-- Emit particles and play sound
	sound:Play()
	woodParticles:Emit(15)
	sparkleParticles:Emit(10)

	-- Clean up
	task.delay(1.5, function()
		if part then part:Destroy() end
	end)
end

return KoalaVFX
