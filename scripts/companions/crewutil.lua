require "/npcs/timers.lua"
dComp = {}
crewutil = {
  weapSlots = {"primary","sheathedprimary","alt","sheathedalt"},
  armorSlots = {"head","headCosmetic","chest","chestCosmetic","legs","legsCosmetic","back","backCosmetic"}
}


timer = createTimers()

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
      table.insert(items[slot], crewutil.dyeUniformItem(item, colorIndex))
    end
  end 

  self.hasArmor, self.hasWeapons, self.emptyHands = crewutil.outfitCheck(items)
  self.items = crewutil.buildItemOverrideTable(items)
  self.planetTypes = {}
  for k,_ in pairs(wardrobeManager.planetTypes) do
    self.planetTypes[k] = true
  end

  self.name = "default"
end

function outfit:toJson(skipTypes)
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
    parameters.scriptConfig.initialStorage.crewUniform = {}
  end
  if path(parameters.scriptConfig,"initialStorage","itemSlots") then
    parameters.scriptConfig.initialStorage.itemSlots = nil
  end
  if path(parameters.scriptConfig,"crew","uniform") then
    parameters.scriptConfig.crew.uniform = {slots = {}}
  end
  setPath(parameters.scriptConfig, "behaviorConfig", "emptyHands", self.emptyHands)
  
  --if self.hasArmor then
  --  setPath(parameters.scriptConfig,"crew","uniformSlots",crewutil.armorSlots)
  --  --setPath(parameters.scriptConfig,"crew","role","uniformColorIndex", "")
  --end
  return parameters
end


function dLog(item, prefix)
  if not prefix then prefix = "" end
  if type(item) ~= "string" then
    sb.logInfo("%s",prefix.."  "..dOut(item))
  else 
    sb.logInfo("%s",prefix.."  "..dOut(item))
  end
end

function dOut(input)
  if not input then input = "" end
  return sb.print(input)
end

function dLogJson(input, prefix, clean)
  local str = "\n"
  if prefix == true or clean == true then clean = 1 else clean = 0 end
  if type(prefix) == "string" then
    str = prefix..str
  end
  if type(input) ~= "table" then return dLog(input, str) end 
  local info = sb.printJson(input, clean)
  sb.logInfo("%s", str..info)
end



function dCompare(prefix, one, two)
  dLog(prefix)
  dComp[type(one)](one) 
  dComp[type(two)](two)
end

function dComp.string(input)
  return dLog(input, "string: ")
end

function dComp.table(input)
  return dLogJson(input, "table")
end

function dComp.number(input)
  return dLog(input, "number")
end

function dComp.boolean(input)
  return dLog(input, "bool: ")
end

function dComp.userdata(input)
  return dLogJson(input, "userdata:")
end

dComp["thread"] = function(input) return dLog(input) end
dComp["function"] = function(input) return sb.logInfo("%s", input) end
dComp["nil"] = function(input) return dLog("nil") end


function getPathStr(t, str)
    if str == "" then return t end
    return jsonPath(t,str) or t[str]
end

function setPathStr(t, str, value)
    if str == "" then t[str] = value return end
    return jsonSetPath(t, str,value)
end

function toHex(v)
  return string.format("%02x", math.min(math.floor(v),255))
end

function toBool(value)
    if value then
      if value == "true" then return true end
      if value == "false" then return false end 
    end
    return nil
end

function logENV()
  for i,v in pairs(_ENV) do
    if type(v) == "function" then
      sb.logInfo("%s", i)
    elseif type(v) == "table" then
      for j,k in pairs(v) do
        sb.logInfo("%s.%s (%s)", i, j, type(k))
      end
    end
  end
end
--outfitCheck
----checks for weapons and armor
----Also sets the emptyHands behaviorConfig
function crewutil.outfitCheck(outfit)
  local hasArmor = false
  local hasWeapons = false
  local emptyHands = false
  hasWeapons = crewutil.tableHasAnyValue(crewutil.weapSlots, outfit)
  hasArmor = crewutil.tableHasAnyValue(crewutil.armorSlots, outfit)
  emptyHands = not((outfit.primary or outfit.alt) and (outfit.sheathedprimary or outfit.sheathedalt))
  return hasArmor, hasWeapons, emptyHands
end

function crewutil.buildItemOverrideTable(t)

  local items = {}
  local container = nil
  t = t or {}

  items.override = {}
  table.insert(items.override, {})
  container = items.override[1]
  table.insert(container, 0)
  table.insert(container, {})
  container = items.override[1][2]
  table.insert(container, t)
  return items
end

function crewutil.buildEquipTable(equipArmor, equipWeap)   
  return {primary = equipWeap,
            alt = equipWeap,
            sheathedprimary = equipWeap,
            sheathedalt = equipWeap,
            head = equipArmor,
            headCosmetic = equipArmor,
            chest = equipArmor,
            chestCosmetic = equipArmor,
            legs = equipArmor,
            legsCosmetic = equipArmor,
            back = equipArmor,
            backCosmetic = equipArmor}
end

function setPath(t, ...)
  local args = {...}
  --sb.logInfo("args are %s", args)
  if #args < 2 then return end

  for i,child in ipairs(args) do
    if i == #args - 1 then
      t[child] = args[#args]
      return
    else
      t[child] = t[child] or {}
      t = t[child]
    end
  end
end

function crewutil.tableHasAnyValue(t1, t2)
  for _,v in ipairs(t1) do
    if type(t2[v]) ~= "nil" then return true end
  end
end

function crewutil.getPlanetTypes()
  local output = {}
  --local asset = root.assetJson("/interface/cockpit/cockpit.config:planetTypeToDescription") 
  local planetTypes = root.assetJson("/terrestrial_worlds.config:planetTypes")
  for _, planetType in pairs(planetTypes) do
    for _,biome in pairs(planetType.layers.surface.primaryRegion) do
      if not output[biome] then 

      end
    end
   
  end

  return output
  -- body
end

function crewutil.getFriendlyBiomeName(planetType)
  
  paths = {"/biomes/surface/%s.biome:friendlyName", "/biomes/space/%s.biome:friendlyName"}
  local success, friendlyName, path
  local foundAsset = false
  for _,v in ipairs(paths) do
    success, friendlyName = getAsset(string.format(v, planetType))
    if success then 
      return friendlyName
    end
  end
  return planetType
end

function getAsset(directory)
  dLog("\n=========== MAKING PCALL ===========\nANY ERROR DISPLAYED WITHIN PCALL WILL NOT EFFECT GAMEPLAY AND CAN BE SAFELY IGNORED")
  local success, asset = pcall(root.assetJson, directory)
  --dLog(friendlyName)
  dLog("=========== END PCALL ===========")
  return success, asset
end

function crewutil.getPlanetType()
  return (world.terrestrial() or nil) and world.type()
end

--identical to recruitable.dyeUniform in terms of function,  moved colorindex to a parameter.
function crewutil.dyeUniformItem(item, colorIndex)
  if not item or not colorIndex then return item end

  local item = copy(item)
  if type(item) == "string" then item = { name = item, count = 1 } end
  item.parameters = item.parameters or {}
  item.parameters.colorIndex = colorIndex

  return item
end

--FUNCTIONS TO REMEMBER--
--[[
============NPC COMBAT BEHAVIOR===========
===  /stagehands/coordinator/npccombat ===
  function rangedWeaponRanges(npcId, ranged)
    local item = world.entityHandItem(npcId, "primary")
    local gunRanges = config.getParameter("npcCombat.rangedWeaponRanges")
    return gunRanges[item] or gunRanges.default
  end
  
  function meleeWeaponRanges(npcId, ranged)
    local item = world.entityHandItem(npcId, "primary")
    local weaponRanges = config.getParameter("npcCombat.meleeWeaponRanges")
    return weaponRanges[item] or weaponRanges.default
  end
--]]