require "/npcs/timers.lua"
require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/scripts/messageutil.lua"

dComp = {}
crewutil = {
	weapSlots = {"primary", "alt", "sheathedprimary", "sheathedalt"},
	armorSlots = {"head","headCosmetic","chest","chestCosmetic","legs","legsCosmetic","back","backCosmetic"},
	itemSlotType =  {"activeitem","activeitem","activeitem","activeitem","headarmor","headarmor","chestarmor","chestarmor","legsarmor","legsarmor","backarmor","backarmor"}
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


function dLogClass(t, prefix, index)
	index = index or 0
	local newIndex = index + 1
	local tType = type(t)
	if index >= 10 then string.format("%s (%s)", prefix, "lmt") return end
	if tType == "function" then
			dLog(string.format("%s (%s)",prefix,"func"))
	elseif tType == "table" then
		if (not isEmpty(t)) and (not prefix:find("__index",1,true)) then
			for k,v in pairs(t) do
				if rawget(t, k) == nil and type(t[k]) == "function" then
					dLogClass(string.format("%s (%s)",prefix.."."..k,"func"))
				elseif rawget(t, k) == nil then
				    dLogClass(string.format("%s (%s)",prefix.."."..k,"__index"))
				else
				    dLogClass(v, string.format("\"%s\"",prefix.."."..k), newIndex)
				end
			end
		else
			dLog(string.format("%s (%s)", prefix, "empty"))
		end
		
	else
		if tType == "string" then
			dLog(string.format("%s = \"%s\"",prefix, t))
		else
			dLog(string.format("%s = %s",prefix, t))
		end
	end
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
function dComp.thread(input) return dLog(input) end

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

function gMatchPlain(str, substr, repl)
	local _, e = str:find(substr, 1, true)
	if e then
		return repl..str:sub(e+1)
	end
	return str
end

function crewutil.formatItemBag(itemBag, prepareItems)
	local output = {}
	for k,v in pairs(itemBag) do
		if v then
			output[k] = {}
			if prepareItems then
				v = crewutil.prepareItem(v)
			end
			table.insert(output[k], v)
		end
	end
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



function crewutil.prepareItem(t)
	if type(t) == "string" then
		t = {name = t, count = 1}
	end
	if type(t) == "table" then
		if t.parameters and t.parameters.directives then return t end
		dLog("Making PCALL - Any Errors shown below can be safely ignored")
		local success, itemType = pcall(root.itemType, t.name)
		if success then
			if itemType ~= "activeitem" then
				local config = root.itemConfig(t.name).config
				if not (config.directives and config.directives ~= "") and config.colorOptions then 
					t.parameters.directives = crewutil.buildDirectiveFromIndex(config.colorIndex, config.colorOptions)
				end
			end
			return t
		end
	end
end

function crewutil.buildDirectiveFromIndex(indx, colorOptions)
	
	indx = (indx and tonumber(indx)) or 1

	local option = colorOptions[indx]
	local str = ";%s;%s"
	local directive = "?replace"
	for k,v in pairs(option) do
		directive = directive..str:format(k,v)
	end
	return directive
end
function crewutil.buildItemOverrideTable(t)
	local items = {}
	local container = nil
	t = t or {}

	for k,v in pairs(t) do
		t[k] = {v}
	end
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
		backCosmetic = equipArmor
			}
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

function crewutil.indexOfMatch(t, input)
	for i,v in ipairs(t) do
		if v == input then
			return i
		end
	end
end

function crewutil.getPlanetTypes()
	local output = copy(crewutil.planetTypes or {})
	if isEmpty(output) then
		--local asset = root.assetJson("/interface/cockpit/cockpit.config:planetTypeToDescription") 
		local planetTypes = root.assetJson("/terrestrial_worlds.config:planetTypes")
		for _, planetType in pairs(planetTypes) do
			for _,biome in pairs(planetType.layers.surface.primaryRegion) do
				if not output[biome] then 
					output[biome] = biome
				end
			end
		end
		--cache it to prevent nasty lookups
		crewutil.planetTypes = copy(output)
	end
	return output
	-- body
end

function crewutil.getFriendlyBiomeName(planetType)
	local paths = {"/biomes/surface/%s.biome:friendlyName", "/biomes/space/%s.biome:friendlyName"}
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

function crewutil.getCelestialBiomeNames(planetType)
	local planetTypeNames = getAsset("/interface/cockpit/cockpit.config:planetTypeNames")
	return planetTypeNames[planetType] or crewutil.getFriendlyBiomeName(planetType)
end

function getAsset(directory, default)
	dLog("\n=========== MAKING PCALL ===========\n"..directory)
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


	local directory, directive, found
	for k,v in ipairs(portrait) do
			found = false
			directory = v.directory
			directive = v.directive
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


	--DEBUG--
	identity.personalityArmIdle, identity.personalityIdle = "idle.1", "idle.1"
	identity.personalityArmOffset = {0,0}
	identity.personalityHeadOffset = {0,0}

	return identity
end

function crewutil.portraitToMannequin(npcPort)
	local replaceArray = {}
	local found = false
	replaceArray["malehead"] = "/humanoid/any/dummyhead.png"
	replaceArray["malebody"] = "/humanoid/any/dummybody.png"
	replaceArray["backarm"] = "/humanoid/any/dummybackarm.png"
	replaceArray["frontarm"] = "/humanoid/any/dummyfrontarm.png"
	
	for i,v in ipairs(npcPort) do
		if isEmpty(replaceArray) then break end
		found = false
		if v.image:find("/humanoid/",1,true) then
			for k,v2 in pairs(replaceArray) do
				if v.image:find(k,10, true) then
					npcPort[i].image = replaceArray[k]
					found = true
					replaceArray[k] = nil
					break
				end
			end
			if not found then
				npcPort[i].image = ""
			end
		end
	end
	return npcPort
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