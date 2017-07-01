--require "/scripts/npcspawnutil.lua"
--I GOT PLANS BABY...I GOT PLANS
require "/scripts/companions/crewutil.lua"



wardrobeManager = {}

Wardrobe = {}
Wardrobe.__index = Wardrobe


Outfit = {}
Outfit.__index = Outfit

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
    local recruit = recruitSpawner:getRecruit(recruitUuId)
    self.needsBuilding = true
    self:buildOutfit(recruit)
  end
end

function Outfit:buildOutfit(recruit)
  local items = {}

  --get starting weapons
  local variant = recruit:createVariant()
  for i, slot in ipairs(crewutil.weapSlots) do
    if variant.items[slot] then
      items[slot] = variant.items[slot].content
    end
  end
  --get starting outfit, building it due to FU not using the items override parameter
  local crewConfig = root.npcConfig(recruit.spawnConfig.type).scriptConfig.crew
  local defaultUniform = crewConfig.defaultUniform
  local colorIndex = crewConfig.role.uniformColorIndex
  for _,slot in ipairs(crewConfig.uniformSlots) do
    local item = defaultUniform[slot]
    if item then
      items[slot] = crewutil.dyeUniformItem(item, colorIndex)
    end
  end 
  dLogJson(items, "buildOutfitItems",true)
  self.hasArmor, self.hasWeapons, self.emptyHands = crewutil.outfitCheck(items)
  self.items = crewutil.buildItemOverrideTable(crewutil.formatItemBag(items))
  dLogJson(items, "self.items:",true)
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
  self.outfits = {}
  self:loadOutfits(recruitUuId, storedWardrobe)
  self.outfitMap = self:mapOutfits()
end

function Wardrobe:loadOutfits(recruitUuId, storedWardrobe)
  if not (storedWardrobe and path(storedWardrobe, "outfits", recruitUuId)) then
    self.outfits["default"] = Outfit.new(recruitUuId)
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

local function getStorageWardrobe()
  dLog("companions:  gettingStorageWardrobe")
  local baseOutfit = {}
  local crew = {}
  local playerInfo = storage.playerInfo or {}

  for k,v in pairs(storage.baseOutfit or {}) do
    baseOutfit[k] = v
  end

  recruitSpawner:forEachCrewMember(function(recruit)
    local crewmember = {}
    		crewmember.identity = recruit.spawnConfig.parameters.identity
    		crewmember.npcType = recruit.spawnConfig.type
    		crewmember.podUuid = recruit.podUuid
    		crewmember.uniqueId = recruit.uniqueId
  	crew[recruit.podUuid] = crewmember
  end)

  return {baseOutfit = baseOutfit, crew = crew, playerInfo = playerInfo}
end

local function setStorageWardrobe(args)
	dLogJson(args, "SET STORAGE:")
	for k,v in pairs(args) do
		storage[k] = v
	end
end

local function clearStorage(args)
	for _,v in pairs(args) do
		storage[v] = nil
	end
end

function wardrobeManager:init()
  clearStorage({"baseOutfit", "wardrobes"})
  message.setHandler("wardrobeManager.getStorage",localHandler(getStorageWardrobe))
  message.setHandler("wardrobeManager.setStorage",localHandler(setStorageWardrobe))
  message.setHandler("debug.clearStorage", localHandler(clearStorage))
  if not storage.wardrobes then storage.wardrobes = {} end
  self.planetTypes = crewutil.getPlanetTypes()
  self.planetType = crewutil.getPlanetType()

  if recruitSpawner then
    dLog("recruitSpawner is a thing")
    self.wardrobes = {}
    for uuid,_ in pairs(recruitSpawner.followers) do
      self.wardrobes[uuid] = Wardrobe.new(uuid) 
    end
    for uuid,_ in pairs(recruitSpawner.shipCrew) do
      self.wardrobes[uuid] = Wardrobe.new(uuid) 
    end
  else
    
  end
  promises:add(wardrobeManager)
end

function wardrobeManager:update(dt)
  return false
end
wardrobeManager.finished = wardrobeManager.update

--first, clean up any residual outfits from crew.
function wardrobeManager:storeWardrobes()
  for uuid, wardrobe in pairs(self.wardrobes) do
    if recruitSpawner:getRecruit(uuid) then
      --storage.wardrobes[uuid] = {}
      storage.wardrobes[uuid] = wardrobe:toJson()
    else
      storage.wardrobes[uuid] = nil
    end
  end
end

function wardrobeManager:getOutfit(uuid)
  return self.wardrobes[uuid]:_getOutfit(self.planetType)
end

function Recruit:_spawn(position, parameters)
  local spawnOutfit = wardrobeManager:getOutfit(self.podUuid)
  if not isEmpty(spawnOutfit) then
    spawnOutfit:overrideParams(parameters)
  end
  --dLogJson(parameters, "Recruit: Spawn: ", true)
  return world.spawnNpc(position, self.spawnConfig.species,  self.spawnConfig.type, parameters.level, self.spawnConfig.seed, parameters)
end

--Essentially the vanilla spawn parameters, gutted some parameter sets due to irrelevency
function Recruit:createVariant()
  local parameters = {}
  util.mergeTable(parameters, self.spawnConfig.parameters)

  local scriptConfig = self:_scriptConfig(parameters)
  parameters.persistent = self.persistent

  scriptConfig.initialStatus = copy(self.status) or {}
  scriptConfig.initialStorage = util.mergeTable(scriptConfig.initialStorage or {}, self.storage or {})

  local variant = self:_createVariant(parameters)
  return variant

end


function Recruit:_createVariant(parameters)
  return root.npcVariant(self.spawnConfig.species, self.spawnConfig.type, parameters.level, self.spawnConfig.seed, parameters)
end


oldInitCE = init
function init()	
	local returnValue = oldInitCE()
 	wardrobeManager:init()
 	return returnValue
end

oldUninitCE = uninit
function uninit()
	wardrobeManager:storeWardrobes()
 	return oldUninitCE()
end