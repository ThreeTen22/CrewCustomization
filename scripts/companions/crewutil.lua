require "/npcs/timers.lua"
require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/scripts/messageutil.lua"

dComp = {}
crewutil = {
  weapSlots = {"primary", "alt", "sheathedprimary", "sheathedalt"},
  armorSlots = {"head","headCosmetic","chest","chestCosmetic","legs","legsCosmetic","back","backCosmetic"}
}
crewutil.itemSlots = util.mergeLists(crewutil.weapSlots, crewutil.armorSlots)


timer = createTimers()

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

function dLogClass(input, prefix, clean)
  local str = "self.%s - %s"
  local output = {}
  for k,v in pairs(input) do
    if type(k) == "string" then
      if type(v) == "table" then
        v = sb.printJson(v, 0)
      end
      table.insert(output, str:format(k, v))
    end
  end

  return dLogJson(output,prefix, clean)
  -- body
end



function dCompare(prefix, ...)
  dLog(prefix)
  local values = {...}
  for _,v in ipairs(values) do
    dComp[type(v)](v)
  end
end

function dComp.string(input) return dLog(input, "string: ") end
function dComp.table(input) return dLogJson(input, "table") end
function dComp.number(input) return dLog(input, "number") end
function dComp.boolean(input) return dLog(input, "bool: ") end
function dComp.userdata(input) return dLogJson(input, "userdata:") end
dComp["thread"] = function(input) return dLog(input) end
dComp["nil"] = function(input) return dLog("nil") end
dComp["function"] = function(input) return sb.logInfo("%s", input) end


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

function crewutil.formatItemBag(itemSlot, itemBag)
  dLog("===formatItemBag===")
  local output = {}
  for i,v in pairs(itemBag) do
    if v then
      local key = itemSlot[i] 
      output[key] = {}
      table.insert(output[key], v)
    end
  end
  dLogJson(output)
  return output
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
--IDENTICAL TO THE FUNCTION IN UTIL.lua, OVERWRITTEN HERE TO REMOVE LOGINFO SPAM
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
        output[biome] = biome
      end
    end
   
  end

  return output
  -- body
end

function crewutil.getFriendlyBiomeName(planetType)
  paths = {"/biomes/surface/%s.biome:friendlyName", "/biomes/space/%s.biome:friendlyName"}
  local friendlyName, path
  local foundAsset = false
  for _,v in ipairs(paths) do
    friendlyName = getAsset(string.format(v, planetType))
    if friendlyName then 
      return friendlyName
    end
  end
  return planetType
end

function getAsset(directory, default)
  dLog("\n=========== MAKING PCALL ===========\nANY ERROR DISPLAYED WITHIN CAN BE SAFELY IGNORED")
  local success, asset = pcall(root.assetJson, directory)
  dLog("\n=========== END PCALL ===========")
  if success then 
    return asset 
  end
  return default
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

function crewutil.sortedTablesByValue(t, valueKey)
  local sortedTable = {}
  local keyTable = {}
  for k, v in pairs(t) do
    local value =  v[valueKey]
    table.insert(sortedTable, value)
    keyTable[value] = k
  end
  if isEmpty(sortedTable) then return nil, nil end
  table.sort(sortedTable)
  dLogJson(sortedTable, "sortedTable\n")
  dLogJson(keyTable, "keyTable  ", true)
  return sortedTable, keyTable
end

function crewutil.subTableElementEqualsValue(t, subTableKey, value, returnKey)
  for k,v in pairs(t) do
    if type(v) == "table" and v[subTableKey] then
      if v[subTableKey] == value then
        if returnKey then
          return true, v[returnKey]
        else
          return true
        end
      end
    end
  end
  return false
end

function crewutil.getPlayerIdentity(portrait)
  local identity = {}
  identity.species = player.species()
  identity.gender = player.gender()
  identity.name = world.entityName(player.id())
  
  
  local genderInfo = getAsset(getSpeciesPath(identity.species, ":genders"))

  util.mapWithKeys(portrait, function(k,v)
      local value = v.image:lower()

      if value:find("malehead.png", 10, true) then
      identity.personalityHeadOffset = v.position
    elseif value:find("arm.png",10, true) then
      identity.personalityArmOffset = v.position
    end

      value = value:match("/humanoid/.-/(.-)%?addmask=.*")
      local directory, idle, directive = value:match("(.+)%.png:(.-)(%?.+)")

    return {directory = directory, idle = idle, directive = directive}
  end, portrait)

  

  for k,v in ipairs(portrait) do
    local found = false
    local directory = v.directory
    local directive = v.directive
    if directory:find("/") then
      local partGroup, partType = directory:match("(.-)/(.+)")
      if partGroup == "hair" then
        identity.hairGroup = partGroup
        identity.hairType = partType
        identity.hairDirectives = directive
        found = true 
      end
      for _,v in ipairs(genderInfo) do
        if found then break end
        for k,v in pairs(v) do
          if v == partGroup then
            identity[k] = partGroup
            identity[k:gsub("Group","Type")] = partType
            identity[k:gsub("Group","Directives")] = directive
            found = true 
            break
          end
        end
      end
    end
  end

  identity.personalityArmIdle = portrait[1].idle
  for k,v in ipairs(portrait) do
    local directory = v.directory
    if directory:find("malebody") then
      identity.personalityIdle = v.idle
      identity.bodyDirectives = v.directive
    elseif directory:find("emote") then
      identity.emoteDirectives = v.directive
    end
  end
  return identity
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