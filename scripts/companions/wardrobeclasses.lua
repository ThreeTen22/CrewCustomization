
require "/scripts/companions/wardrobe.lua"

Outfits, Crewmember, wardrobeManager = {}, {}, {}
Crewmember.__index = Crewmember
Outfits.__index = Outfits
wardrobeManager.__index = wardrobeManager


local function setStorageWardrobe(args)
	dLogJson(args, "SET STORAGE:")
	for k,v in pairs(args) do
		storage[k] = v
	end
end

function getStorageWardrobe()
	dLog("companions:  gettingStorageWardrobe")
	local crew = {}
	local wardrobes = storage.wardrobe or {}
	recruitSpawner:forEachCrewMember(
	function(recruit)
		local crewmember = {}
		crewmember.identity = recruit.spawnConfig.parameters.identity
		crewmember.npcType = recruit.spawnConfig.type
		crewmember.podUuid = recruit.podUuid
		crewmember.uniqueId = recruit.uniqueId
		crewmember.seed = recruit.spawnConfig.seed
		crew[recruit.podUuid] = crewmember
	end)
	return {crew = crew, wardrobe = wardrobe}
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

function Outfits:init(...)

	self.outfits = {}
	self:load("outfits", Outfit)

	self.playerParameters = nil
end

function Outfits:load(key, class)
	dLogJson("LOADING Outfits - LOAD")
	for k,v in pairs(storage[key] or {}) do
		self[key][k] = class.new(v)
	end
end

function Outfits:addUnique(key, class, storedValue)
	local newClass = class.new(storedValue)
	local uId = newClass.uniqueId
	self[key][uId] = newClass
	return self[key][uId]
end

function Outfits:loadPlayer(step)
	if step == 1 then
		status.addEphemeralEffect("nude", 5.0)
	elseif step == 2 then
		local initTable = {}
		local playerUuid = player.uniqueId() 
		local bustPort = world.entityPortrait(player.id(), "bust")
		initTable.portrait = world.entityPortrait(player.id(), "head")
		status.removeEphemeralEffect("nude") 
		initTable.identity = crewutil.getPlayerIdentity(bustPort)
		initTable.npcType = "nakedvillager"
		initTable.podUuid = playerUuid
		self.playerParameters = copy(initTable)
		return self:addUnique("crew", Crewmember, initTable)
	end
end

function Outfits:setDisplayName(uId, displayName)
	if self.outfits[uId] then
		self.outfits[uId].displayName = displayName
	end
end

function Outfits:getOutfit(podUuid)
	return self.outfits[podUuid]
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
