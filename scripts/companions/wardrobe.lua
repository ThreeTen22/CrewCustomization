require "/scripts/companions/outfit.lua"

Wardrobe = {
    itemSlots = {"head","headCosmetic","chest","chestCosmetic","legs","legsCosmetic","back","backCosmetic"},
    uniform = {},
    equipment = {},
    overrides = {}
}
Wardrobe.__index = Wardrobe


function Wardrobe.new(...)
	local self = setmetatable({}, Wardrobe)
	self:init(...)
	return self
end

function Wardrobe:init(recruitUuid, storedWardrobe)
    storedWardrobe = storedWardrobe or (storage.wardrobe and storage.wardrobe.recruitUuid) or {}
    self.podUuid = recruitUuid
	self:load(recruitUuid, storedWardrobe)
	--self.outfitMap = self:mapOutfits()
end

function Wardrobe:load(recruitUuid, storedWardrobe)
    for biomeType, outfitUuid in pairs(storedWardrobe.uniform or {}) do 
        self.uniform[biomeType] = outfitUuid
    end
    for biomeType, outfitUuid in pairs(storedWardrobe.equipment or {}) do 
        self.equipment[biomeType] = outfitUuid
    end

    if isEmpty(self.uniform) then 
        self.uniform["default"] = Outfits:add("outfit", recruitUuid)
    end
end


function Wardrobe:toJson()
	local json = {uniform = {}, equipment = {}}
	json.outfitMap = self.outfitMap
	for biomeType,OutfitUuid in pairs(self.uniform) do
        json.uniform[biomeType] = OutfitUuid
    end
    for biomeType,OutfitUuid in pairs(self.equipment) do
        json.equipment[biomeType] = OutfitUuid
    end
	return json
  -- body
end

function Wardrobe:_getOutfit()
	local outfitName = "default"
	return self.uniform[outfitName]
end


--[[


function Wardrobe.new(...)
	local self = setmetatable({}, Wardrobe)
	self:init(...)
	return self
end

function Wardrobe:init(recruitUuId, storedWardrobe)
	storedWardrobe = storedWardrobe or storage.wardrobes[recruitUuId]
	self.uniform = {}
	self.outfits = {}
	self:load(recruitUuId, storedWardrobe)
	self.outfitMap = self:mapOutfits()
end

function Wardrobe:load(recruitUuId, storedWardrobe)

	if not (storedWardrobe and path(storedWardrobe, "outfits", recruitUuId)) then
		self.uniform = Uniform.new(recruitUuId)
		return
	end
	for k,v in pairs(storedWardrobe.outfits[recruitUuId]) do
		self.outfits[k] = Outfit.new(recruitUuId, v)
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


function Wardrobe:mapOutfits(recruitUuId)
	local outfitMap = {}
	for planet,_ in pairs(wardrobeManager.planetTypes) do
		for outfitName, outfit in pairs(self.outfits) do
			if outfit.planetTypes[planet] then
				outfitMap[planet] = outfitName
			end
		end
	end
	return outfitMap
end

]]