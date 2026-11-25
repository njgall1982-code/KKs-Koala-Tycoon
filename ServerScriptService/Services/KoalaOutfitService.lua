local KoalaOutfitService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local OutfitShopConfig = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("OutfitShopConfig"))

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

-- Unequip any outfit currently on the koala in the given slot (e.g. "Hat", "Necklace")
function KoalaOutfitService.UnequipOutfit(koala, slot)
	slot = slot or "Hat"

	-- Legacy cleanup (for old single-outfit attribute and model name)
	if slot == "Hat" then
		local legacyModel = koala:FindFirstChild("EquippedOutfitModel")
		if legacyModel then
			legacyModel:Destroy()
		end
		if koala:GetAttribute("EquippedOutfit") then
			koala:SetAttribute("EquippedOutfit", nil)
		end
	end

	local modelName = "EquippedOutfitModel_" .. slot
	local existing = koala:FindFirstChild(modelName)
	if existing then
		existing:Destroy()
	end
	koala:SetAttribute("EquippedOutfit_" .. slot, nil)
end

-- Equip a specified outfit to the koala
function KoalaOutfitService.EquipOutfit(koala, outfitName)
	if not outfitName or outfitName == "" then
		return
	end

	local config = OutfitShopConfig.GetOutfit(outfitName)
	local slot = config and config.Type or "Hat"

	-- Remove existing in this slot first
	KoalaOutfitService.UnequipOutfit(koala, slot)

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
	outfitModel.Name = "EquippedOutfitModel_" .. slot

	-- Convert Accessory to Model and strip default avatar tags so Roblox Humanoid
	-- doesn't auto-rescale or auto-weld accessories on custom rigs
	if outfitModel:IsA("Accessory") then
		local newModel = Instance.new("Model")
		newModel.Name = outfitModel.Name
		for attrName, attrVal in pairs(outfitModel:GetAttributes()) do
			newModel:SetAttribute(attrName, attrVal)
		end
		for _, child in ipairs(outfitModel:GetChildren()) do
			child.Parent = newModel
		end
		outfitModel:Destroy()
		outfitModel = newModel
	end

	local handle = nil
	if outfitModel:IsA("Tool") then
		handle = outfitModel:FindFirstChild("Handle")
	elseif outfitModel:IsA("Model") then
		handle = outfitModel.PrimaryPart or outfitModel:FindFirstChild("Handle") or outfitModel:FindFirstChildOfClass("BasePart")
		if handle then outfitModel.PrimaryPart = handle end
	elseif outfitModel:IsA("BasePart") then
		handle = outfitModel
	end

	if not handle then
		warn("[KoalaOutfitService] Outfit template has no valid handle (PrimaryPart/Handle/BasePart): " .. outfitName)
		outfitModel:Destroy()
		return
	end

	-- Strip avatar scaling / weld tags from handle
	for _, desc in ipairs(handle:GetChildren()) do
		if desc.Name == "OriginalSize" or desc.Name == "AvatarPartScaleType" or desc.Name == "HatAttachment" or desc.Name == "AccessoryWeld" then
			desc:Destroy()
		end
	end

	local attachPartName = outfitModel:GetAttribute("AttachPart") or "head"
	local target = koala:FindFirstChild(attachPartName, true)
	if not target then
		-- Fallback to head bone/part names
		target = koala:FindFirstChild("CC_Base_Head", true) or koala:FindFirstChild("char1", true) or koala:FindFirstChild("HumanoidRootPart")
	end

	outfitModel.Parent = koala

	-- 1. Weld all parts to the handle first (while in their correct template relative positions) and configure collisions
	for _, part in ipairs(outfitModel:GetDescendants()) do
		if part:IsA("BasePart") then
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

	-- 2. Position the outfit (using PivotTo for models, preserving relative welded positions)
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
		if outfitModel:IsA("Model") then
			outfitModel:PivotTo(target.CFrame * offset)
		else
			handle.CFrame = target.CFrame * offset
		end

		local weld = Instance.new("WeldConstraint")
		weld.Name = "OutfitWeld"
		weld.Part0 = handle
		weld.Part1 = target
		weld.Parent = handle
	end

	-- 3. Unanchor all parts now that they are welded and correctly positioned
	for _, part in ipairs(outfitModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end

	koala:SetAttribute("EquippedOutfit_" .. slot, outfitName)
	print(string.format("[KoalaOutfitService] Equipped outfit '%s' onto adult koala '%s' in slot '%s'", outfitName, koala:GetAttribute("DisplayName") or koala.Name, slot))
end

-- ============================================================
-- UNLOCK OUT_FITS / PICKUPS
-- ============================================================

-- Helper function to safely get and migrate UnlockedOutfits to a dictionary
local function getUnlockedOutfitsDict(player)
	local unlockedStr = player:GetAttribute("UnlockedOutfits") or "{}"
	local unlocked = {}
	pcall(function()
		unlocked = HttpService:JSONDecode(unlockedStr)
	end)

	-- If it's a legacy array, migrate it to a dictionary
	local isArray = false
	if unlocked and next(unlocked) ~= nil then
		if type(next(unlocked)) == "number" then
			isArray = true
		end
	end

	if isArray then
		local dict = {}
		for _, name in ipairs(unlocked) do
			dict[name] = (dict[name] or 0) + 1
		end
		unlocked = dict
		player:SetAttribute("UnlockedOutfits", HttpService:JSONEncode(unlocked))
	end

	return unlocked
end

-- Unlock/Add an outfit for a specific player
function KoalaOutfitService.UnlockOutfit(player, outfitName)
	if not player or not outfitName or outfitName == "" then return end

	local unlocked = getUnlockedOutfitsDict(player)
	unlocked[outfitName] = (unlocked[outfitName] or 0) + 1
	player:SetAttribute("UnlockedOutfits", HttpService:JSONEncode(unlocked))
	print(string.format("[KoalaOutfitService] Player %s gained outfit: %s (Now owns: %d)", player.Name, outfitName, unlocked[outfitName]))

	-- Show quest or chat notification if needed
	local signals = ServerStorage:FindFirstChild("Signals")
	local updateQuest = signals and signals:FindFirstChild("UpdateQuest")
	if updateQuest then
		updateQuest:Fire(player, "🎉 Gained Outfit: " .. outfitName .. "! Equip it on your adult koalas.")
		task.spawn(function()
			task.wait(5)
			-- Clear notification if they haven't gotten another quest update
			if player:GetAttribute("DataLoaded") then
				updateQuest:Fire(player, "")
			end
		end)
	end
end

-- Expose dict getter for client/other scripts
function KoalaOutfitService.GetUnlockedOutfits(player)
	return getUnlockedOutfitsDict(player)
end

-- ============================================================
-- INITIALIZE
-- ============================================================

function KoalaOutfitService.Initialize()
	-- Listen for equip requests from clients (optional slot parameter for unequipping)
	equipOutfitRequest.OnServerEvent:Connect(function(player, koala, outfitName, slot)
		if not koala or not koala:IsDescendantOf(workspace) then return end

		-- Safety verification: Is it a Koala?
		if not (koala:IsA("Model") and (koala.Name:find("Koala") or koala.Name:find("KK") or CollectionService:HasTag(koala, "KoalaNPC"))) then
			return
		end

		-- Verify stage: Only Adult koalas can wear outfits
		local stage = koala:GetAttribute("Stage") or 1
		if stage ~= 4 then
			warn(string.format("[KoalaOutfitService] Player %s tried to dress up non-adult koala '%s'", player.Name, koala.Name))
			return
		end

		local unlocked = getUnlockedOutfitsDict(player)

		-- Resolve slot/type
		local config = outfitName and outfitName ~= "" and OutfitShopConfig.GetOutfit(outfitName)
		local resolvedSlot = slot
		if config then
			resolvedSlot = config.Type or resolvedSlot or "Hat"
		else
			resolvedSlot = resolvedSlot or "Hat"
		end

		-- Load current outfit in slot, with backward compatibility fallback for Hat
		local currentOutfit = koala:GetAttribute("EquippedOutfit_" .. resolvedSlot)
		if not currentOutfit and resolvedSlot == "Hat" then
			currentOutfit = koala:GetAttribute("EquippedOutfit")
		end
		currentOutfit = currentOutfit or ""

		if outfitName == "" or outfitName == nil then
			-- Unequip request
			if currentOutfit ~= "" then
				-- Return old outfit to player's unassigned inventory
				unlocked[currentOutfit] = (unlocked[currentOutfit] or 0) + 1
				player:SetAttribute("UnlockedOutfits", HttpService:JSONEncode(unlocked))
				KoalaOutfitService.UnequipOutfit(koala, resolvedSlot)
			end
		else
			-- Equip request
			if currentOutfit == outfitName then
				-- Already wearing this; do nothing or refresh weld
				KoalaOutfitService.EquipOutfit(koala, outfitName)
				return
			end

			-- Check if player has the requested outfit available in inventory
			local count = unlocked[outfitName] or 0
			if count <= 0 then
				warn(string.format("[KoalaOutfitService] Player %s tried to equip locked/unavailable outfit '%s'", player.Name, tostring(outfitName)))
				return
			end

			-- Return old outfit to inventory if replacing
			if currentOutfit ~= "" then
				unlocked[currentOutfit] = (unlocked[currentOutfit] or 0) + 1
			end

			-- Deduct new outfit from inventory
			unlocked[outfitName] = count - 1

			player:SetAttribute("UnlockedOutfits", HttpService:JSONEncode(unlocked))
			KoalaOutfitService.EquipOutfit(koala, outfitName)
		end
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
				outfitName = (strVal.Value ~= "") and strVal.Value or strVal.Name
			end
		end

		-- Second Fallback: If no string value or attribute, use the parent model/accessory name
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
