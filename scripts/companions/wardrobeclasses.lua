
require "/scripts/companions/wardrobe.lua"

Crewmember, wardrobeManager = {}, {}
Crewmember.__index = Crewmember
Outfits = {
	uniform = {},
	equipment = {},
	outfit = {}
}
Outfits.__index = Outfits
wardrobeManager.__index = wardrobeManager


local function setStorageWardrobe(args)
	dLogJson(args, "SET STORAGE:")
	for k,v in pairs(args) do
		storage[k] = v
	end
end

function clearStorage(args)
	for _,v in pairs(args) do
		storage[v] = nil
	end
end

function wardrobeManager:init()
	if recruitSpawner then
		message.setHandler("wardrobeManager.getStorage",localHandler(getStorageWardrobe))
		message.setHandler("wardrobeManager.setStorage",localHandler(setStorageWardrobe))
		message.setHandler("wardrobeManager.getOutfit", function(_,isLocal,...) if isLocal then return wardrobeManager:getOutfit(...) end; end)
		message.setHandler("debug.clearStorage", localHandler(clearStorage))
	end
	if not storage.wardrobes then storage.wardrobes = {} end
	self.planetTypes = crewutil.getPlanetTypes()
	self.planetType = crewutil.getPlanetType()
	self:load()
	promises:add(wardrobeManager)
end

function wardrobeManager:update(dt)
	return false
end

function wardrobeManager:load()
	self.wardrobes = {}
		for uuid,_ in pairs(recruitSpawner.followers or {}) do
			dLog(uuid,  "wardrobeManager - recruitSpawner")
			self.wardrobes[uuid] = Wardrobe.new(uuid) 
		end
		for uuid,_ in pairs(recruitSpawner.shipCrew or {}) do
			dLog(uuid,  "wardrobeManager - recruitSpawner")
			self.wardrobes[uuid] = Wardrobe.new(uuid) 
		end
end
wardrobeManager.finished = wardrobeManager.update

--first, clean up any residual outfits from crew.

function wardrobeManager:getOutfit(uuid)
	if self.wardrobes[uuid] then
		return self.wardrobes[uuid]:_getOutfit(self.planetType)
	end
end

function wardrobeManager:storeWardrobes()
	for uuid, wardrobe in pairs(self.wardrobes) do
		if (recruitSpawner and recruitSpawner:getRecruit(uuid)) then
			storage.wardrobes[uuid] = wardrobe:toJson()
  		else
  			storage.wardrobes[uuid] = nil
  		end
	end
end




--[[

==  Outfits ==

--]]

function Outfits.new(key, Class)
	local self = setmetatable({}, Outfits)
	self:init(key, Class)
	return self
end

function Outfits:init(key, Class)
	self.Class = Class or Outfit
	self:load()
end

function Outfits:load(key)
	for k,v in pairs(storage[key] or {}) do
		self[key][k] = self.Class.new(v)
	end
end

function Outfits:add(key, ...)
	local newClass = self.Class.new(...)
	local uuid = newClass.uuid
	self[key][uuid] = newClass
	return self[key][uuid]
end

function Outfits:setDisplayName(uId, displayName)
	if self.outfits[uId] then
		self.outfits[uId].displayName = displayName
	end
end

function Outfits:get(Uuid)
	return self.outfits[Uuid]
end


function Outfits:forEachElementInTable(tableName, func)
	for k,v in pairs(self[tableName]) do
		if func(v) then
		  return
		end
	end
end

function Outfits:deleteOutfit(uId)
	if uId then
		self.uniform[uId] = nil
	end
end
