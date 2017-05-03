--require "/scripts/npcspawnutil.lua"
--I GOT PLANS BABY...I GOT PLANS


wardrobeManager = {}

wardrobe = {}
wardrobe.__index = wardrobe


outfit = {}
outfit.__index = outfit

function outfit.new(...)
  local self = setmetatable({}, outfit)
  self:init(...)
  return self
end

function outfit:init(recruitUuId,storedOutfit)
	if storedOutfit then
		self.hasArmor = storedOutfit.hasArmor
		self.hasWeapons = storedOutfit.hasWeapons
		self.items = storedOutfit.items
		self.planetTypes = storeOutfit.planetTypes
		self.name = storeOutfit.name
	else	
		local recruit = recruitSpawner:getRecruit(recruitUuId)
		self:buildOutfit(recruit)
	end
end

function outfit:buildOutfit(recruit)
	local items = {}

	--get starting weapons
	local variant = recruit:createVariant()

	for i, slot in ipairs(crewutil.weapSlots) do
		if variant.items[slot] then
			items[slot] = jarray()
			table.insert(items[slot], variant.items[slot].content)
		end
	end
	--get starting outfit, building it due to FU not using the items override parameter
	local crewConfig = root.npcConfig(recruit.spawnConfig.type).scriptConfig.crew
	local defaultUniform = crewConfig.defaultUniform
	local colorIndex = crewConfig.role.uniformColorIndex
	for _,slot in ipairs(crewConfig.uniformSlots) do
		local item = defaultUniform[slot]
		if item then
			items[slot] = jarray()
			table.insert(items[slot], crewutil.dyeUniformItem(items[slot], colorIndex))
		end
	end	

	self.hasArmor, self.hasWeapons, self.emptyHands = crewutil.outfitCheck(items)
	self.items = crewutil.buildItemOverrideTable(items)

	self.planetTypes = copy(wardrobeManager.planetTypes)
	self.name = "default"
end

function outfit:toJson()
local json = {}
	json.items = self.items
	json.hasArmor = self.hasArmor
	json.hasWeapons = self.hasWeapons
	json.emptyHands = self.emptyHands
	json.planetTypes = self.planetTypes
	json.name = self.name
	return json
end

function outfit:overrideParams(parameters)
	local items = self.items
	parameters.items = items

	if path(parameters.scriptConfig,"initialStorage","crewUniform") then
		parameters.scriptConfig.initialStorage.crewUniform = nil
	end
	if path(parameters.scriptConfig,"crew","uniform") then
		parameters.scriptConfig.crew.uniform = {slots = {}}
	end
	setPath(parameters.scriptConfig, "behaviorConfig", "emptyHands", self.emptyHands)
	
	if self.hasArmor then
		setPath(parameters.scriptConfig,"crew","uniformSlots",{})
	else
		local slots = path(parameters.scriptConfig,"crew","uniformSlots")
		if slots and jsize(slots) == 0 then parameters.scriptConfig.crew.uniformSlots = nil end
	end
	return parameters
end

function wardrobe.new(...)
  local self = setmetatable({}, wardrobe)
  self:init(...)
  return self
end

function wardrobe:init(recruitUuId)
	local storedWardrobe = storage.wardrobes[recruitUuId]
	self.outfits = {}
	self:loadOutfits(recruitUuId, storedWardrobe)
	self.outfitMap = self:mapOutfits()
end

function wardrobe:loadOutfits(recruitUuId, storedWardrobe)
	if not (storedWardrobe and storedWardrobe.outfits[recruitUuId]) then
		self.outfits["default"] = outfit.new(recruitUuId)
		return
	end
	for k,v in pairs(storedWardrobe.outfits[recruitUuId]) do
		self.outfits[k] = outfit.new(recruitUuId, v)
	end
end


function wardrobe:getOutfit()
	return self.outfitMap[wardrobeManager.planetType]
end


function wardrobe:mapOutfits(recruitUuId)
	local outfitMap = {}
	for planet,_ in pairs(wardrobeManager.planetTypes) do
		for k, outfit in pairs(self.outfits) do
			if outfit.planetTypes[planet] then
				outfitMap[planet] = outfit
			end
		end
	end
	return outfitMap
end

function wardrobeManager:init()
	if not storage.wardrobes then storage.wardrobes = {} end
	self.planetTypes = crewutil.getPlanetTypes()
	self.planetType = crewutil.getPlanetType()
	self.wardrobes = {}

	for uuid, follower in pairs(recruitSpawner.followers) do
		self.wardrobes[uuid] = wardrobe.new(uuid) 
	end
	for uuid, follower in pairs(recruitSpawner.shipCrew) do
		self.wardrobes[uuid] = wardrobe.new(uuid) 
	end


	promises:add(wardrobeManager)
end

function wardrobeManager:update(dt)
	return false
end
wardrobeManager.finished = wardrobeManager.update

--first, clean up any residual outfits from crew.
function wardrobeManager:storeOutfits()
	for uuid, wardrobe in pairs(self.wardrobes) do
		if recruitSpawner:getRecruit(uuid) then
			if not storage.wardrobes[uuid] then
				storage.wardrobes[uuid] = {}
				storage.wardrobes[uuid].outfits = wardrobe:toJson()
			end
		else
			storage.outfits[uuid] = nil
		end
	end
end

function wardrobeManager:getOutfit(uuid)
	local wardrobe = self.wardrobes[uuid]
	return wardrobe:getOutfit(wardrobeManager.planetType)
end


local oldInitCE = init
function init()
	require "/scripts/companions/crewutil.lua"
	local returnValue = oldInitCE()
 	wardrobeManager:init()
 	return returnValue
end


local oldUninitCE = uninit
function uninit()
 	return oldUninitCE()
end


function Recruit:_createVariant(parameters)
	local variant = root.npcVariant(self.spawnConfig.species, self.spawnConfig.type, parameters.level, self.spawnConfig.seed, parameters)
	return variant
end


function Recruit:_spawn(position, parameters)
	local params = copy(parameters)
	local outfit = wardrobeManager:getOutfit(self.podUuid)
	if outfit then
		outfit:overrideParams(params)
	end
	return world.spawnNpc(position, self.spawnConfig.species, self.spawnConfig.type, parameters.level, self.spawnConfig.seed, parameters)
end

--Essentially the vanilla spawn parameters, gutted for the purpose of creating a variant npc
function Recruit:createVariant()
  local parameters = {}
  util.mergeTable(parameters, self.spawnConfig.parameters)

  local scriptConfig = self:_scriptConfig(parameters)
  parameters.persistent = self.persistent

  scriptConfig.initialStatus = copy(self.status) or {}
  scriptConfig.initialStorage = util.mergeTable(scriptConfig.initialStorage or {}, self.storage or {})

  --[[
  if getPetPersistentEffects then
    parameters.level = 1
  end
  if self.spawner.levelOverride then
    parameters.level = self.spawner.levelOverride
  end

  scriptConfig.initialStatus.persistentEffects = self:getPersistentEffects()

  local damageTeam = self:damageTeam()
  parameters.damageTeamType = damageTeam.type
  parameters.damageTeam = damageTeam.team
  parameters.relocatable = false

  if self.collar and self.collar.parameters then
    util.mergeTable(parameters, self.collar.parameters)
  end
  --]]

  local variant = self:_createVariant(parameters)
  return variant

end