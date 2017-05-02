dComp = {}
crewutil = {}
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
  if toBool(clean) or toBool(prefix) then clean = 1 else clean = 0 end
  if prefix ~= "true" and prefix ~= "false" and prefix then
    str = prefix..str
  end
   local info = sb.printJson(input, clean)
   sb.logInfo("%s", str..info)
end

function dPrintJson(input)
  local info = sb.printJson(input,1)
  sb.logInfo("%s",info)
  return info
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




function getAsset(assetPath)
  return root.assetJson(assetPath)
end

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

function crewutil.outfitCheck(outfit)
  local hasArmor = false
  local hasWeapons = false
  local weapSlots = {"primary","sheathedprimary","alt","sheathedalt"}
  local armorSlots = {"head","headCosmetic","chest","chestCosmetic","legs","legsCosmetic","back","backCosmetic"}
  hasWeapons = crewutil.tableHasAnyValue(weapSlots, outfit)
  hasArmor = crewutil.tableHasAnyValue(armorSlots, outfit)
  return hasArmor, hasWeapons
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

function crewutil.getPlanetType()
  return world.terrestrial() and world.planetType()
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