--require "/scripts/npcspawnutil.lua"
--I GOT PLANS BABY...I GOT PLANS
require "/scripts/companions/crewutil.lua"

WardrobeManager = {}

Wardrobe = {}
Wardrobe.__index = Wardrobe

Uniform = {
  uniformItems = {}
}

Uniform.__index = Uniform

function Uniform.new(...)
  local self = setmetatable({}, Uniform)
  self:init(...)
  return self
end

function Uniform:init(recruitUuId,storedUniform)
  if storedOutfit then
    self.hasArmor = storedOutfit.hasArmor
    self.hasWeapons = storedOutfit.hasWeapons
    self.emptyHands = storedOutfit.emptyHands
    self.items = storedOutfit.items
    self.name = storeOutfit.name
  else
    local recruit = recruitSpawner:getRecruit(recruitUuId)
    self:buildUniform(recruit)
  end
end

Outfit = {}
Outfit.__index = Outfit

function Outfit.new(...)
  local self = setmetatable({}, Outfit)
  self:init(...)
  return self
end

function Outfit:init(recruitUuId,storedOutfit)
  if storedOutfit then
    self.hasArmor = storedOutfit.hasArmor
    self.hasWeapons = storedOutfit.hasWeapons
    self.emptyHands = storedOutfit.emptyHands
    self.items = storedOutfit.items
    self.name = storeOutfit.name
    self.planetTypes = storeOutfit.planetTypes
  else
    local recruit = recruitSpawner:getRecruit(recruitUuId)
    self:buildOutfit(recruit)
  end
end

function Outfit:buildOutfit(recruit)
  local items = {}

  --get starting weapons
  local variant = recruit:createVariant()

  for i, slot in ipairs(crewutil.weapSlots) do
    if variant.items[slot] then
      items[slot] = jarray()
      table.insert(items[slot], variant.items[slot].content)
    end
  end
  --get starting Outfit, building it due to FU not using the items override parameter
  local crewConfig = root.npcConfig(recruit.spawnConfig.type).scriptConfig.crew
  local defaultUniform = crewConfig.defaultUniform
  local colorIndex = crewConfig.role.uniformColorIndex
  for _,slot in ipairs(crewConfig.uniformSlots) do
    local item = defaultUniform[slot]
    if item then
      items[slot] = jarray()
      table.insert(items[slot], crewutil.dyeUniformItem(item, colorIndex))
    end
  end 

  self.hasArmor, self.hasWeapons, self.emptyHands = crewutil.outfitCheck(items)
  self.items = crewutil.buildItemOverrideTable(items)
  self.planetTypes = {}
  for k,_ in pairs(WardrobeManager.planetTypes) do
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
  setPath(parameters.scriptConfig, "behaviorConfig", "emptyHands", (self.emptyHands == true))
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
  local outfitName = self.outfitMap[WardrobeManager.planetType] or "default"
  return self.outfits[outfitName]
end


function Wardrobe:mapOutfits(recruitUuId)
  local outfitMap = {}
  for planet,_ in pairs(WardrobeManager.planetTypes) do
    for outfitName, Outfit in pairs(self.outfits) do
      if Outfit.planetTypes[planet] then
        outfitMap[planet] = outfitName
      end
    end
  end
  return outfitMap
end

function getStorageWardrobe()
  dLog("companions:  gettingStorageWardrobe")
  local baseOutfit = {}
  local crewmembers = {}
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
  	crewmembers[#crewmembers+1] = crewmember
  end)

  return {baseOutfit = baseOutfit, crewmembers = crewmembers, playerInfo = playerInfo}
end

function setStorageWardrobe(args)
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

function WardrobeManager:init()
  clearStorage({"baseOutfit"})
  message.setHandler("WardrobeManager.getStorage",localHandler(getStorageWardrobe))
  message.setHandler("WardrobeManager.setStorage",localHandler(setStorageWardrobe))
  message.setHandler("debug.clearStorage", localHandler(clearStorage))
  if not storage.wardrobes then storage.wardrobes = {} end
  self.planetTypes = crewutil.getPlanetTypes()
  self.planetType = crewutil.getPlanetType()

  if recruitSpawner then
    self.wardrobes = {}
    for uuid,_ in pairs(recruitSpawner.followers) do
      self.wardrobes[uuid] = Wardrobe.new(uuid) 
    end
    for uuid,_ in pairs(recruitSpawner.shipCrew) do
      self.wardrobes[uuid] = Wardrobe.new(uuid) 
    end
  else
    
  end
  promises:add(WardrobeManager)
end

function WardrobeManager:update(dt)
  return false
end
WardrobeManager.finished = WardrobeManager.update

--first, clean up any residual outfits from crew.
function WardrobeManager:storeWardrobes()
  for uuid, Wardrobe in pairs(self.wardrobes) do
    if recruitSpawner:getRecruit(uuid) then
      --storage.wardrobes[uuid] = {}
      storage.wardrobes[uuid] = Wardrobe:toJson()
    else
      storage.wardrobes[uuid] = nil
    end
  end
end

function WardrobeManager:getOutfit(uuid)
  local Wardrobe = self.wardrobes[uuid]
  return Wardrobe:_getOutfit(self.planetType)
end

function Recruit:_spawn(position, parameters)
  local Outfit = WardrobeManager:getOutfit(self.podUuid)
  if Outfit then
    Outfit:overrideParams(parameters)
  end
  dLogJson(parameters, "Recruit: Spawn: ", true)
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


local oldInitCE = init

function init()	
	local returnValue = oldInitCE()
 	WardrobeManager:init()
 	return returnValue
end

local oldUninitCE = uninit;

function uninit()
	WardrobeManager:storeWardrobes()
 	return oldUninitCE()
end

function offerUniformUpdate(recruitUuid, entityId)
	local recruit = recruitSpawner:getRecruit(recruitUuid)
  if not recruit then return end
  local config = getAsset("/objects/crew/outfitpane.config", nil)
  if config then
    player.interact("ScriptPane", getAsset("/objects/crew/outfitpane.config"), entityId)
    promises:add(world.sendEntityMessage(entityId, "recruit.confirmFollow", true))
  end
end