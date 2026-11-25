-- OutfitShopConfig.lua
-- Configuration for outfits purchasable in the Koala Outfit Shop.
local OutfitShopConfig = {}

-- Rarity definitions and color coding for UI
OutfitShopConfig.RARITIES = {
	Common = {
		Name = "Common",
		Color = Color3.fromRGB(180, 180, 180),
		DefaultBonus = 0.10, -- +10%
	},
	Uncommon = {
		Name = "Uncommon",
		Color = Color3.fromRGB(80, 220, 100),
		DefaultBonus = 0.20, -- +20%
	},
	Rare = {
		Name = "Rare",
		Color = Color3.fromRGB(70, 160, 255),
		DefaultBonus = 0.35, -- +35%
	},
	Epic = {
		Name = "Epic",
		Color = Color3.fromRGB(180, 70, 255),
		DefaultBonus = 0.60, -- +60%
	},
	Legendary = {
		Name = "Legendary",
		Color = Color3.fromRGB(255, 200, 30),
		DefaultBonus = 1.00, -- +100%
	},
}

-- Pricing structure & Display details for each outfit
OutfitShopConfig.Items = {
	["Top Hat"] = {
		Name = "Top Hat",
		DisplayName = "🎩 Top Hat",
		Price = 50,
		Type = "Hat",
		Rarity = "Common",
		Bonus = 0.10,
	},
	["Party hat"] = {
		Name = "Party hat",
		DisplayName = "🥳 Party Hat",
		Price = 80,
		Type = "Hat",
		Rarity = "Common",
		Bonus = 0.10,
	},
	["Cowboy Hat"] = {
		Name = "Cowboy Hat",
		DisplayName = "🤠 Cowboy Hat",
		Price = 120,
		Type = "Hat",
		Rarity = "Common",
		Bonus = 0.12,
	},
	["Bowtie"] = {
		Name = "Bowtie",
		DisplayName = "🎀 Bowtie",
		Price = 150,
		Type = "Necklace",
		Rarity = "Common",
		Bonus = 0.15,
	},
	["Christmas hat"] = {
		Name = "Christmas hat",
		DisplayName = "🎅 Christmas Hat",
		Price = 200,
		Type = "Hat",
		Rarity = "Uncommon",
		Bonus = 0.20,
	},
	["Queen Tiara"] = {
		Name = "Queen Tiara",
		DisplayName = "👑 Queen Tiara",
		Price = 250,
		Type = "Hat",
		Rarity = "Uncommon",
		Bonus = 0.22,
	},
	["King's Crown"] = {
		Name = "King's Crown",
		DisplayName = "👑 King's Crown",
		Price = 300,
		Type = "Hat",
		Rarity = "Uncommon",
		Bonus = 0.25,
	},
	["Wizard Hat"] = {
		Name = "Wizard Hat",
		DisplayName = "🧙 Wizard Hat",
		Price = 400,
		Type = "Hat",
		Rarity = "Rare",
		Bonus = 0.35,
	},
	["Hungry Dino"] = {
		Name = "Hungry Dino",
		DisplayName = "🦖 Hungry Dino",
		Price = 500,
		Type = "Hat",
		Rarity = "Rare",
		Bonus = 0.40,
	},
	["Pirate Parrot"] = {
		Name = "Pirate Parrot",
		DisplayName = "🦜 Pirate Parrot",
		Price = 600,
		Type = "Hat",
		Rarity = "Rare",
		Bonus = 0.45,
	},
	["Ice Gold Necklace"] = {
		Name = "Ice Gold Necklace",
		DisplayName = "❄️✨ Ice Gold Necklace",
		Price = 900,
		Type = "Necklace",
		Rarity = "Epic",
		Bonus = 0.60,
	},
	["Neon Bracelet"] = {
		Name = "Neon Bracelet",
		DisplayName = "💫 Neon Bracelet",
		Price = 900,
		Type = "Necklace",
		Rarity = "Epic",
		Bonus = 0.60,
	},
	["Heart Necklace"] = {
		Name = "Heart Necklace",
		DisplayName = "💖 Heart Necklace",
		Price = 1000,
		Type = "Necklace",
		Rarity = "Epic",
		Bonus = 0.70,
	},
}

-- Returns details for a specific outfit
function OutfitShopConfig.GetOutfit(outfitName)
	return OutfitShopConfig.Items[outfitName]
end

-- Returns bonus decimal (e.g. 0.25 for +25%)
function OutfitShopConfig.GetOutfitBonus(outfitName)
	local item = OutfitShopConfig.Items[outfitName]
	if not item then return 0 end
	if item.Bonus then return item.Bonus end
	local r = OutfitShopConfig.RARITIES[item.Rarity or "Common"]
	return r and r.DefaultBonus or 0.10
end

-- Returns rarity table
function OutfitShopConfig.GetOutfitRarity(outfitName)
	local item = OutfitShopConfig.Items[outfitName]
	local rarityKey = item and item.Rarity or "Common"
	return OutfitShopConfig.RARITIES[rarityKey] or OutfitShopConfig.RARITIES.Common
end

-- Returns list of all outfits sorted by price
function OutfitShopConfig.GetAllOutfits()
	local list = {}
	for _, item in pairs(OutfitShopConfig.Items) do
		table.insert(list, item)
	end
	table.sort(list, function(a, b)
		return a.Price < b.Price
	end)
	return list
end

return OutfitShopConfig
