
require "/scripts/companions/wardrobe.lua"

outfitManager, Crewmember, wardrobeManager, Outfit = {}, {}, {}
Crewmember.__index = Crewmember


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
	
	if recruitSpawner then
		for uuid,_ in pairs(recruitSpawner.followers or {}) do
			dLog(uuid,  "wardrobeManager - recruitSpawner")
			self.wardrobes[uuid] = Wardrobe.new(uuid) 
		end
		for uuid,_ in pairs(recruitSpawner.shipCrew or {}) do
			dLog(uuid,  "wardrobeManager - recruitSpawner")
			self.wardrobes[uuid] = Wardrobe.new(uuid) 
		end
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

==  crewmember ==

--]]
function Crewmember.new(...)
	local self = setmetatable({},Crewmember)
	self:init(...)
	return self
end

function Crewmember:init(stored)
	self.podUuid = stored.podUuid
	self.npcType = stored.npcType
	self.identity = stored.identity
	self.portrait = stored.portrait
	self.uniqueId = stored.uniqueId
	self.seed = stored.seed
end

function Crewmember:toJson()
	local json = {
		podUuid = self.podUuid,
		npcType = self.npcType,
		identity = self.identity,
		portrait = self.portrait,
		uniqueId = self.uniqueId,
		seed = self.seed
	}
	return json
end

function Crewmember:getPortrait(portraitType, items)
	local parameters = {identity = self.identity}
	parameters.items = items

	return root.npcPortrait(portraitType, self.identity.species, self.npcType, 1, 1, parameters)
end

function Crewmember:getVariant(items)
	local parameters = {}
	parameters.identity = self.identity
	return root.npcVariant(self.identity.species, self.npcType, 1, self.seed, parameters)
end

function Crewmember:swapGender()
	local gender = self.identity.gender or self:getVariant().humanoidIdentity.gender
	if gender == "female" then 
		gender = "male"
	else
		gender = "female"
	end
	self.identity.gender = gender
	-- body
end



--[[

==  outfitManager ==

--]]

function outfitManager:init(...)
	self.crew = {}
	self.outfits = {}
	self.uniforms = {}
	self.playerParameters = nil
end

function outfitManager:load(key, class)
	dLogJson("LOADING OUTFITMANAGER - LOAD")
	for k,v in pairs(storage[key]) do
		self[key][k] = class.new(v)
	end
end

function outfitManager:addUnique(key, class, storedValue)
	local newClass = class.new(storedValue)
	local uId = newClass.podUuid
	self[key][uId] = newClass
	return self[key][uId]
end

function outfitManager:loadPlayer(step)
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

function outfitManager:setDisplayName(uId, displayName)
	if self.uniform[uId] then
		self.uniform[uId].displayName = displayName
	end
end

function outfitManager:getUniform(podUuid)
	return self.uniform[podUuid]
end

function outfitManager:getCrewmember(podUuid)
	return self.crew[podUuid]
end

function outfitManager:forEachElementInTable(tableName, func)
	for k,v in pairs(self[tableName]) do
		if func(v) then
		  return
		end
	end
end

function outfitManager:deleteOutfit(uId)
	if uId then
		self.uniform[uId] = nil
	end
end

function outfitManager:getTailorInfo(podUuid)
	local tailor = nil
	if podUuid then
		tailor = self.crew[podUuid]
	else
		self:forEachElementInTable("crew", 
		function(recruit)
			if recruit.npcType == "crewmembertailor" then
				tailor = recruit
				return true
			end
		end)
	end
	return tailor
end

