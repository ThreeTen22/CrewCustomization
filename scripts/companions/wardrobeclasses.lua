
outfitManager, Uniform, Crewmember, wardrobeManager, Outfit, Wardrobe  = {}, {}, {}, {}, {}, {}


Uniform.__index = Uniform
Crewmember.__index = Crewmember
Outfit.__index = Outfit
Wardrobe.__index = Wardrobe


local function setStorageWardrobe(args)
	dLogJson(args, "SET STORAGE:")
	for k,v in pairs(args) do
		storage[k] = v
	end
end

function getStorageWardrobe()
	dLog("companions:  gettingStorageWardrobe")
	local uniform = storage.uniform or {}
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
	return {uniform = uniform, crew = crew, wardrobe = wardrobe}
end

function clearStorage(args)
	for _,v in pairs(args) do
		storage[v] = nil
	end
end

--[[

==  Uniform ==

--]]
function Uniform.new(...)
	local self = setmetatable({},Uniform)
	self:init(...)
	return self
end

function Uniform:init(stored)
	stored = stored or config.getParameter("Uniform", {})
	self.items = stored.items
	self.podUuid = stored.podUuid or sb.makeUuid()
	self.displayName = stored.displayName
end

function Uniform:toJson()
	local json = {}
	json.items = self.items
	json.podUuid = self.podUuid
	json.displayName = self.displayName
	return json
end

function Outfit.new(...)
	local self = setmetatable({}, Outfit)
	self:init(...)
	return self
end

function Outfit:init(recruitUuId,storedOutfit)
	if storedOutfit then
		self.needsBuilding = false
		self.podUuid = recruitUuId
		self.hasArmor = storedOutfit.hasArmor
		self.hasWeapons = storedOutfit.hasWeapons
		self.items = storedOutfit.items
		self.planetTypes = storeOutfit.planetTypes
		self.name = storeOutfit.name
	else
		local recruit
		if recruitSpawner then
			recruit = recruitSpawner:getRecruit(recruitUuId)
		else
			recruit = outfitManager.crew[recruitUuId]
		end
		self.needsBuilding = true
		self:buildOutfit(recruitUuId)
	end
end

function Outfit:buildOutfit(recruit)
	if recruitSpawner then
		recruit = recruitSpawner:getRecruit(recruit)
	else
		recruit = outfitManager.crew[recruit]
	end
	local items = {}
	local crewConfig, defaultUniform, colorIndex
	--get starting weapons
	local variant
	--dLogClass(recruit, "buildOutfit - recruit")
	if recruit.createVariant then
		variant = recruit:createVariant()
		crewConfig = root.npcConfig(recruit.spawnConfig.type).scriptConfig.crew or {}
	else
		variant = recruit:getVariant({})
		crewConfig = root.npcConfig(recruit.npcType).scriptConfig.crew or {}
	end
	for i, slot in ipairs(crewutil.weapSlots) do
		if variant.items[slot] then
			items[slot] = variant.items[slot].content
		end
	end
	--get starting outfit, building it due to FU not using the items override parameter
	if not isEmpty(crewConfig) then
		defaultUniform = crewConfig.defaultUniform
		colorIndex = crewConfig.role.uniformColorIndex
		for _,slot in ipairs(crewConfig.uniformSlots) do
			local item = defaultUniform[slot]
			if item then
				items[slot] = crewutil.dyeUniformItem(item, colorIndex)
			end
		end 
	end
	self.hasArmor, self.hasWeapons, self.emptyHands = crewutil.outfitCheck(items)
	self.items = crewutil.buildItemOverrideTable(crewutil.formatItemBag(items))
	self.planetTypes = {}
	for k,_ in pairs(wardrobeManager.planetTypes) do
		self.planetTypes[k] = true
	end

	self.name = "default"
end


function Outfit:toJson(skipTypes)
	local json = {}
	json.items = self.items
	json.hasArmor = self.hasArmor
	json.hasWeapons = self.hasWeapons
	json.emptyHands = self.emptyHands
	json.planetTypes = self.planetTypes
	json.name = self.name
	return json
end

function Outfit:overrideParams(parameters)
	local items = self.items
	parameters.items = items
	if path(parameters.scriptConfig,"initialStorage","crewUniform") then
		parameters.scriptConfig.initialStorage.crewUniform = {}
	end
	if path(parameters.scriptConfig,"initialStorage","itemSlots") then
		parameters.scriptConfig.initialStorage.itemSlots = nil
	end
	if path(parameters.scriptConfig,"crew","uniform") then
		parameters.scriptConfig.crew.uniform = {slots = {}}
	end
	setPath(parameters.scriptConfig, "behaviorConfig", "emptyHands", self.emptyHands)

	return parameters
end



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
	else
		for uuid,_ in pairs(outfitManager.crew or {}) do
			dLog(uuid,  "wardrobeManager - outfitManager")
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
		if (recruitSpawner and recruitSpawner:getRecruit(uuid)) or (outfitManager.crew and outfitManager.crew[uuid]) then
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
	local config = config.getParameter("outfitManager")
	for k,v in pairs(config) do
		self[k] = v
	end
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

