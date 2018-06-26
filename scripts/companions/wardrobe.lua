require "/scripts/companions/outfit.lua"
Wardrobe = {
    itemSlots = {"head","headCosmetic","chest","chestCosmetic","legs","legsCosmetic","back","backCosmetic"},
    uniform = {
        follower = {},
        shipCrew = {}
    }
}
Wardrobe.__index = Wardrobe


function Wardrobe.new(...)
	local self = setmetatable({}, Wardrobe)
	self:init(...)
	return self
end

function Wardrobe:init(recruitUuId, storedWardrobe)
    storedWardrobe = storedWardrobe or storage.wardrobes[recruitUuId]
    self.podUuid = recruitUuId
	self:load(recruitUuId, storedWardrobe)
	--self.outfitMap = self:mapOutfits()
end

function Wardrobe:load(recruitUuId, storedWardrobe)

    for k,v in pairs(storedWardrobe.uniform) do 
        self.uniform[k] = v
    end
    for k,v in pairs(storedWardrobe.overrides) do 
        self.overrides[k] = v
    end
end


function Wardrobe:toJson()
	local json = {outfits = {}}
	json.outfitMap = self.outfitMap
	for k,v in pairs(self.outfits) do
		json.outfits[k] = v:toJson()
	end
	return json
  -- body
end

function Wardrobe:_getOutfit()
	local outfitName = self.outfitMap[wardrobeManager.planetType] or "default"
	return self.outfits[outfitName]
end
