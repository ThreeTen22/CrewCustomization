--require "/scripts/npcspawnutil.lua"
--I GOT PLANS BABY...I GOT PLANS


wardrobeManager = {}

wardrobe = {}
wardrobe.__index = outfit


outfit = {}
outfit.__index = outfit

function outfit.new(...)
  local self = setmetatable({}, outfit)
  self:init(...)
  return self
end

function outfit:init(storedOutfit)
	if storedOutfit then
		self.hasArmor = storedOutfit.hasArmor
		self.hasWeapons = storedOutfit.hasWeapons
		self.items = storedOutfit.items
		self.planetTypes = storeOutfit.planetTypes
		self.name = storeOutfit.name
	else	
		self:buildOutfit()
	end
end

function outfit:buildOutfit()
	local items = {}

	--get starting weapons
	local variant = self:createVariant()

	for i, slot in ipairs(crewutil.weapSlots) do
		if variant.items[slot] then
			items[slot] = {},
			table.insert(items[slot], variant.items[slot].content)
		end
	end
	--get starting outfit, building it due to FU not using the items override parameter
	local defaultUniform = self.spawnConfig.scriptConfig.crew.defaultUniform
	local colorIndex = self.spawnConfig.scriptConfig.crew.role.uniformColorIndex
	for _,slot in ipairs(self.spawnConfig.scriptConfig.crew.uniformSlots) do
		local item = defaultUniform[slot]
		if item then
			items[slot] = {}
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
		setPath(parameters.scriptConfig,"crew","uniformSlots",{})
	end
	return parameters
end

function wardrobe.new(...)
  local self = setmetatable({}, wardrobe)
  self:init(...)
  return self
end

function wardrobe:init(recruitUuId)
	for uuid, follower in pairs(recruitSpawner.followers)
		local storedWardrobe = storage.wardrobes[uuid]
		self.outfits = outfit.new(recruitUuId, storedWardrobe)
	end
	self:mapOutfits()
end

function wardrobe:mapOutfits(recruitUuId)
	local outfitMap = {}
	for _,v in ipairs(self.outfits) do
		outfitMap[v] = {}
	end

end


function wardrobeManager:init()
	if not storage.wardrobes then storage.wardrobes = {} end
	self.planetTypes = crewutil.getPlanetTypes()
	self.planetType = crewutil.getPlanetType()
	self.wardrobes = {}

	for uuid, follower in pairs(recruitSpawner.followers) do
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
	for uuid, outfit in pairs(self.outfits) do
		if recruitSpawner:getRecruit(uuid) then
			if not storage.outfits[uuid] then
				storage.outfits[uuid] = {}
				storage.outfits[uuid].default = outfit:toJson()
			end
		else
			storage.outfits[uuid] = nil
		end
	end
end

function wardrobeManager:getOutfit(uuid)
	return self.outfits[uuid]
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
 	debugOut()
 	return oldUninitCE()
end


function debugOut(args)
	if not args then args = {storage = true, json = true} end
	if args.storage then
		dLog("----STORAGE----")
		for k,v in pairs(storage.outfits) do
			dLogJson(v, dOut(k), true)
		end
	end
end

--Essentially the vanilla spawn parameters, gutted for the purpose of creating a variant npc
function Recruit:createVariant()
  local parameters = {}
  util.mergeTable(parameters, self.spawnConfig.parameters)

  local scriptConfig = self:_scriptConfig(parameters)
  parameters.persistent = self.persistent

  scriptConfig.initialStatus = copy(self.status) or {}
  scriptConfig.initialStorage = util.mergeTable(scriptConfig.initialStorage or {}, self.storage or {})

  -- Pets level with the player, gaining the effects of the player's armor
  if getPetPersistentEffects then
    -- If the player is spawning us, we gain the effects of their armor, so
    -- ignore the monster's level.
    parameters.level = 1
  end
  if self.spawner.levelOverride then
    -- If a tether is spawning us, we get the level of the world/ship we're on.
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

  local variant = self:_createVariant(parameters)
  return variant

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

