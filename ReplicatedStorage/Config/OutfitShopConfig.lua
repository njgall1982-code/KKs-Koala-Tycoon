-- OutfitShopConfig.lua
-- Configuration for outfits purchasable in the Koala Outfit Shop.
local OutfitShopConfig = {}

-- Pricing structure & Display details for each outfit
OutfitShopConfig.Items = {
	["Top Hat"] = {
		Name = "Top Hat",
		DisplayName = "🎩 Top Hat",
		Price = 50,
		Type = "Hat",
	},
	["Party hat"] = {
		Name = "Party hat",
		DisplayName = "🥳 Party Hat",
		Price = 80,
		Type = "Hat",
	},
	["Cowboy Hat"] = {
		Name = "Cowboy Hat",
		DisplayName = "🤠 Cowboy Hat",
		Price = 120,
		Type = "Hat",
	},
	["Christmas hat"] = {
		Name = "Christmas hat",
		DisplayName = "🎅 Christmas Hat",
		Price = 200,
		Type = "Hat",
	},
	["Queen Tiara"] = {
		Name = "Queen Tiara",
		DisplayName = "👑 Queen Tiara",
		Price = 250,
		Type = "Hat",
	},
	["King's Crown"] = {
		Name = "King's Crown",
		DisplayName = "👑 King's Crown",
		Price = 300,
		Type = "Hat",
	},
	["Wizard Hat"] = {
		Name = "Wizard Hat",
		DisplayName = "🧙 Wizard Hat",
		Price = 400,
		Type = "Hat",
	},
	["Ice Gold Necklace"] = {
		Name = "Ice Gold Necklace",
		DisplayName = "❄️✨ Ice Gold Necklace",
		Price = 900,
		Type = "Necklace",
	},
	["Hungry Dino"] = {
		Name = "Hungry Dino",
		DisplayName = "🦖 Hungry Dino",
		Price = 500,
		Type = "Hat",
	},
	["Pirate Parrot"] = {
		Name = "Pirate Parrot",
		DisplayName = "🦜 Pirate Parrot",
		Price = 600,
		Type = "Hat",
	},
	["Neon Bracelet"] = {
		Name = "Neon Bracelet",
		DisplayName = "💫 Neon Bracelet",
		Price = 900,
		Type = "Necklace",
	},
	["Heart Necklace"] = {
		Name = "Heart Necklace",
		DisplayName = "💖 Heart Necklace",
		Price = 1000,
		Type = "Necklace",
	},
}

-- Returns details for a specific outfit
function OutfitShopConfig.GetOutfit(outfitName)
	return OutfitShopConfig.Items[outfitName]
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
