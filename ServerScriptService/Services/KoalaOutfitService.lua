local KoalaOutfitService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

-- Remote Events
local equipOutfitRequest = ReplicatedStorage:FindFirstChild("EquipOutfitRequest")
if not equipOutfitRequest then
	equipOutfitRequest = Instance.new("RemoteEvent")
	equipOutfitRequest.Name = "EquipOutfitRequest"
	equipOutfitRequest.Parent = ReplicatedStorage
end

-- ============================================================
-- OUTFIT EQUIPMENT LOGIC
-- ============================================================

-- Unequip any outfit currently on the koala
function KoalaOutfitService.UnequipOutfit(koala)
	local existing = koala:FindFirstChild("EquippedOutfitModel")
	if existing then
		existing:Destroy()
	end
	koala:SetAttribute("EquippedOutfit", nil)
end

-- Equip a specified outfit to the koala
function KoalaOutfitService.EquipOutfit(koala, outfitName)
	-- Remove existing first
	KoalaOutfitService.UnequipOutfit(koala)

	if not outfitName or outfitName == "" then
		return
	end

	-- Outfits are restricted to Adult koalas (Stage 4)
	local stage = koala:GetAttribute("Stage") or 1
	if stage ~= 4 then
		warn(string.format("[KoalaOutfitService] Attempted to equip outfit '%s' on non-adult koala '%s' (Stage %d)", outfitName, koala.Name, stage))
		return
	end

	local outfitsFolder = ReplicatedStorage:FindFirstChild("KoalaOutfits")
	if not outfitsFolder then
		warn("[KoalaOutfitService] KoalaOutfits folder not found in ReplicatedStorage!")
		return
	end

	local template = outfitsFolder:FindFirstChild(outfitName)
	if not template then
		warn("[KoalaOutfitService] Outfit template not found: " .. tostring(outfitName))
		return
	end

	-- Clone and position outfit
	local outfitModel = template:Clone()
	outfitModel.Name = "EquippedOutfitModel"

	local handle = nil
	if outfitModel:IsA("Accessory") or outfitModel:IsA("Tool") then
		handle = outfitModel:FindFirstChild("Handle")
	elseif outfitModel:IsA("Model") then
		handle = outfitModel.PrimaryPart or outfitModel:FindFirstChildOfClass("BasePart")
	elseif outfitModel:IsA("BasePart") then
		handle = outfitModel
	end

	if not handle then
		warn("[KoalaOutfitService] Outfit template has no valid handle (PrimaryPart/Handle/BasePart): " .. outfitName)
		outfitModel:Destroy()
		return
	end

	local attachPartName = outfitModel:GetAttribute("AttachPart") or "head"
	local target = koala:FindFirstChild(attachPartName, true)
	if not target then
		-- Fallback to head bone/part names
		target = koala:FindFirstChild("CC_Base_Head", true) or koala:FindFirstChild("char1", true) or koala:FindFirstChild("HumanoidRootPart")
	end

	outfitModel.Parent = koala

	-- Handle weld attachment based on target type
	if target:IsA("Bone") or target:IsA("Attachment") then
		local attach = handle:FindFirstChild("Attach")
		if not attach then
			attach = Instance.new("Attachment")
			attach.Name = "Attach"
			attach.Parent = handle
		end

		local constraint = Instance.new("RigidConstraint")
		constraint.Name = "OutfitConstraint"
		constraint.Attachment0 = attach
		constraint.Attachment1 = target
		constraint.Parent = handle
	else
		-- Standard CFrame Weld for BaseParts
		local offset = outfitModel:GetAttribute("AttachOffset") or CFrame.new()
		handle.CFrame = target.CFrame * offset

		local weld = Instance.new("WeldConstraint")
		weld.Name = "OutfitWeld"
		weld.Part0 = handle
		weld.Part1 = target
		weld.Parent = handle
	end

	-- Weld all other parts in the outfit to the handle and ensure they are unanchored/non-collidable
	for _, part in ipairs(outfitModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
			if part ~= handle then
				local w = Instance.new("WeldConstraint")
				w.Part0 = part
				w.Part1 = handle
				w.Parent = part
			end
		end
	end

	koala:SetAttribute("EquippedOutfit", outfitName)
	print(string.format("[KoalaOutfitService] Equipped outfit '%s' onto adult koala '%s'", outfitName, koala:GetAttribute("DisplayName") or koala.Name))
end

-- ============================================================
-- UNLOCK OUT_FITS / PICKUPS
-- ============================================================

-- Unlock an outfit for a specific player
function KoalaOutfitService.UnlockOutfit(player, outfitName)
	if not player or not outfitName or outfitName == "" then return end

	local unlockedStr = player:GetAttribute("UnlockedOutfits") or "[]"
	local unlocked = {}
	pcall(function()
		unlocked = HttpService:JSONDecode(unlockedStr)
	end)

	-- Check if already unlocked
	local found = false
	for _, name in ipairs(unlocked) do
		if name == outfitName then
			found = true
			break
		end
	end

	if not found then
		table.insert(unlocked, outfitName)
		player:SetAttribute("UnlockedOutfits", HttpService:JSONEncode(unlocked))
		print(string.format("[KoalaOutfitService] Player %s unlocked outfit: %s", player.Name, outfitName))

		-- Show quest or chat notification if needed
		local signals = ServerStorage:FindFirstChild("Signals")
		local updateQuest = signals and signals:FindFirstChild("UpdateQuest")
		if updateQuest then
			updateQuest:Fire(player, "🎉 Found Outfit: " .. outfitName .. "! Equip it on your adult koalas.")
			task.spawn(function()
				task.wait(5)
				-- Clear notification if they haven't gotten another quest update
				if player:GetAttribute("DataLoaded") then
					updateQuest:Fire(player, "")
				end
			end)
		end
	end
end

-- ============================================================
-- INITIALIZE
-- ============================================================

function KoalaOutfitService.Initialize()
	-- Listen for equip requests from clients
	equipOutfitRequest.OnServerEvent:Connect(function(player, koala, outfitName)
		if not koala or not koala:IsDescendantOf(workspace) then return end

		-- Safety verification: Is it a Koala?
		if not (koala:IsA("Model") and (koala.Name:find("Koala") or koala.Name:find("KK") or CollectionService:HasTag(koala, "KoalaNPC"))) then
			return
		end

		-- Verify ownership/unlock
		local unlockedStr = player:GetAttribute("UnlockedOutfits") or "[]"
		local unlocked = {}
		pcall(function()
			unlocked = HttpService:JSONDecode(unlockedStr)
		end)

		local isUnlocked = false
		if outfitName == "" or outfitName == nil then
			isUnlocked = true -- Unequip is always allowed
		else
			for _, name in ipairs(unlocked) do
				if name == outfitName then
					isUnlocked = true
					break
				end
			end
		end

		if not isUnlocked then
			warn(string.format("[KoalaOutfitService] Player %s tried to equip locked outfit '%s'", player.Name, tostring(outfitName)))
			return
		end

		-- Verify stage: Only Adult koalas can wear outfits
		local stage = koala:GetAttribute("Stage") or 1
		if stage ~= 4 then
			warn(string.format("[KoalaOutfitService] Player %s tried to dress up non-adult koala '%s'", player.Name, koala.Name))
			return
		end

		-- Apply equipment
		KoalaOutfitService.EquipOutfit(koala, outfitName)
	end)

	-- Handle Outfit Pickups via ProximityPrompts globally
	local ProximityPromptService = game:GetService("ProximityPromptService")
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		-- Check if prompt is tagged as outfit pickup or has relevant attributes/children
		local isPickup = CollectionService:HasTag(prompt, "OutfitPickup") 
			or prompt:GetAttribute("OutfitName") 
			or (prompt.Parent and prompt.Parent:GetAttribute("OutfitName"))
			or prompt:FindFirstChildOfClass("StringValue")
			or (prompt.Parent and prompt.Parent:FindFirstChildOfClass("StringValue"))

		if not isPickup then return end

		-- Determine Outfit Name
		local outfitName = prompt:GetAttribute("OutfitName") or (prompt.Parent and prompt.Parent:GetAttribute("OutfitName"))
		
		if not outfitName or outfitName == "" then
			-- Fallback: Look for a StringValue inside the prompt or parent
			local strVal = prompt:FindFirstChildOfClass("StringValue") or (prompt.Parent and prompt.Parent:FindFirstChildOfClass("StringValue"))
			if strVal then
				-- If the Value is set, use it; otherwise, use the StringValue's Name!
				outfitName = (strVal.Value ~= "") and strVal.Value or strVal.Name
			end
		end

		-- Second Fallback: If no string value or attribute, use the parent model/accessory name!
		if not outfitName or outfitName == "" then
			if prompt.Parent and (prompt.Parent:IsA("Model") or prompt.Parent:IsA("Accessory")) then
				outfitName = prompt.Parent.Name
			end
		end

		if outfitName and outfitName ~= "" then
			KoalaOutfitService.UnlockOutfit(player, outfitName)
		end
	end)

	-- Connect layout configurations for any incoming tagged ProximityPrompts
	local function setupPickupPrompt(prompt)
		if CollectionService:HasTag(prompt, "OutfitPickup") then
			local outfitName = prompt:GetAttribute("OutfitName") or "Outfit"
			prompt.ObjectText = "Outfit Pickup"
			prompt.ActionText = "Collect " .. outfitName
			prompt.HoldDuration = 0
			prompt.RequiresLineOfSight = false
		end
	end

	CollectionService:GetInstanceAddedSignal("OutfitPickup"):Connect(setupPickupPrompt)
	for _, prompt in ipairs(CollectionService:GetTagged("OutfitPickup")) do
		if prompt:IsA("ProximityPrompt") then
			setupPickupPrompt(prompt)
		end
	end

	print("[KoalaOutfitService] Initialized.")
end

return KoalaOutfitService
