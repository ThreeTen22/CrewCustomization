--require "/scripts/npcspawnutil.lua"
--I GOT PLANS BABY...I GOT PLANS

wardrobeManager = {}

wardrobe = {}
wardrobe.__index = wardrobe

function wardrobe.new(...)
  local self = setmetatable({}, wardrobe)
  self:init(...)
  return self
end

function wardrobe:init(recruitUuId, storedWardrobe)
  storedWardrobe = storedWardrobe or storage.wardrobes[recruitUuId]
  self.outfits = {}
  self:loadOutfits(recruitUuId, storedWardrobe)
  self.outfitMap = self:mapOutfits()
end

function wardrobe:loadOutfits(recruitUuId, storedWardrobe)
  if not (storedWardrobe and path(storedWardrobe, "outfits", recruitUuId)) then
    self.outfits["default"] = outfit.new(recruitUuId)
    return
  end
  for k,v in pairs(storedWardrobe.outfits[recruitUuId]) do
    self.outfits[k] = outfit.new(recruitUuId, v)
  end
end


function wardrobe:toJson()
  local json = {outfits = {}}
  json.outfitMap = self.outfitMap
  for k,v in pairs(self.outfits) do
    json.outfits[k] = v:toJson()
  end
  return json
  -- body
end

function wardrobe:_getOutfit()
  local outfitName = self.outfitMap[wardrobeManager.planetType] or "default"
  return self.outfits[outfitName]
end


function wardrobe:mapOutfits(recruitUuId)
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
  local wardrobes = {}
  local baseOutfits = {}
  local identities = {}

  for k,v in pairs(storage.wardrobes or {}) do
    wardrobes[k] = v
  end

  for k,v in pairs(storage.baseOutfits or {}) do
    baseOutfits[k] = v
  end

  recruitSpawner:forEachCrewMember(function(recruit)
  	identities[recruit.podUuid] = copy(recruit.spawnConfig.parameters.identity)
  end)

  return {wardrobes = wardrobes, baseOutfits = baseOutfits, identities = identities}
end

function wardrobeManager:init()
  message.setHandler("wardrobeManager.getStorage",localHandler(getStorageWardrobe))

  if not storage.wardrobes then storage.wardrobes = {} end
  self.planetTypes = crewutil.getPlanetTypes()
  self.planetType = crewutil.getPlanetType()

  if recruitSpawner then
    self.wardrobes = {}
    for uuid,_ in pairs(recruitSpawner.followers) do
      self.wardrobes[uuid] = wardrobe.new(uuid) 
    end
    for uuid,_ in pairs(recruitSpawner.shipCrew) do
      self.wardrobes[uuid] = wardrobe.new(uuid) 
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
  local wardrobe = self.wardrobes[uuid]
  return wardrobe:_getOutfit(self.planetType)
end

function Recruit:_spawn(position, parameters)
  local outfit = wardrobeManager:getOutfit(self.podUuid)
  if outfit then
    outfit:overrideParams(parameters)
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
	require "/scripts/companions/crewutil.lua"
	local returnValue = oldInitCE()
 	wardrobeManager:init()
 	return returnValue
end

local oldUninitCE = uninit
function uninit()
	wardrobeManager:storeWardrobes()
	--dLogJson(getStorageWardrobe(), "storedWardrobes", true)
 	return oldUninitCE()
end