require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/scripts/messageutil.lua"
require "/scripts/companions/crewutil.lua"

--[[NOTES:
	timer can be manipulated to use coroutines.  give coroutine as function,  pass coroutine in as variable
--]]
outfitManager, baseOutfit, crewmember, refreshManager, visibilityManager = {}, {}, {}, {}, {}
outfitManager.__index = outfitManager
baseOutfit.__index = baseOutfit
crewmember.__index = crewmember
refreshManager.__index = refreshManager
visibilityManager.__index = visibilityManager
--[[

==  LOCAL FUNCTIONS ==
(Will not display in _ENV)

--]]
local function getSpeciesPath(species, subPath)          
    return string.format("/species/%s.species%s",species,subPath)
end

local function getSelectedListData(listPath)
	local itemId = widget.getListSelected(listPath)
	if itemId then
		local fullpath = string.format("%s.%s", listPath, itemId)
		return widget.getData(fullpath)
	end
end


function init()
	if not storage then storage = {} end
	self = config.getParameter("initVars")
	self.itemBagStorage = widget.itemGridItems("itemGrid")
	outfitManager:init()
	refreshManager:init()
	visibilityManager:init()
	outfitManager:loadPlayer(1)
	promises:add(world.sendEntityMessage(pane.playerEntityId(), "wardrobeManager.getStorage"), outfitInit)
	return
end

function update(dt)
	promises:update()
	timer.tick(dt)
	refreshManager:update()
end

function outfitInit(args)
	dLogJson("updateInit", args, true)
	storage.baseOutfit = args.baseOutfit or {}
	storage.crew = args.crew or {}

	outfitManager:loadPlayer(2)
	outfitManager:load("crew", crewmember)
	outfitManager:load("baseOutfit", baseOutfit)
	outfitManager:getTailorInfo()
	listOutfits()

	update = updateMain
end

function updateMain()
	local itemBag = widget.itemGridItems("itemGrid")
	if checkForItemChanges(itemBag) then
		local outfit = outfitManager:getSelectedOutfit()
		if outfit then
			outfit.items = itemBag
			refreshManager:queue("updatePortrait", updatePortrait)
		end
		
	end
	self.itemBagStorage = widget.itemGridItems("itemGrid")
	promises:update()
	timer.tick(dt)
	refreshManager:update()
	return 
end
--[[

==  visibilityManager ==

--]]

function visibilityManager:init()
	local config = config.getParameter("visibilityManager")
	config.dummy = nil
	for k,v in pairs(config) do
		self[k] = v
	end
end

function visibilityManager:setVisible(key, bool)
	for _,v in pairs(self[key]) do
		widget.setVisible(v, bool)
	end
end

--[[

==  refreshManager ==

--]]
function refreshManager:init()
	self.updateTable = {}
end

function refreshManager:notQueued(key)
	return not self.updateTable[key]
end

function refreshManager:queue(key, func)
	if self:notQueued(key) then
		self.updateTable[key] = func
	end
end

function refreshManager:update()
	local updateTable = self.updateTable
	self.updateTable = {}
	for _,func in pairs(updateTable) do
		if type(func) == "function" then
			func()
		elseif type(func) == "table" then
			local args = func.args
			func.func(args)
		end
	end
	-- body
end

--[[

==  crewmember ==

--]]

function crewmember.new(...)
	local self = setmetatable({},crewmember)
	self:init(...)
	return self
end

function crewmember:init(stored)
	self.podUuid = stored.podUuid
	self.npcType = stored.npcType
	self.identity = stored.identity
	self.portrait = stored.portrait
	self.uniqueId = stored.uniqueId
end

function crewmember:getPortrait(portraitType, naked)
	local parameters = {identity = self.identity}

	return root.npcPortrait(portraitType, self.identity.species, self.npcType, 1, 1, parameters)
end

--[[

==  baseOutfit ==

--]]

function baseOutfit.new(...)
	local self = setmetatable({},baseOutfit)
	self:init(...)
	return self
end

function baseOutfit:init(stored)
	stored = stored or {}
	self.items = stored.items or {}
	self.podUuid = stored.podUuid or sb.makeUuid()
	self.displayName = stored.displayName or "-- CHANGE ME --"
	self.listItem = nil
end

function baseOutfit:toJson()
	local json = {}
	json.items = self.items
	json.podUuid = self.podUuid
	json.displayName = self.displayName
	return json
end

--[[

==  outfitManager ==

--]]

function outfitManager:init(...)
	self.crew = {}
	self.baseOutfit = {}
	self.widgetItems = {}
	self.playerParameters = nil
	self.listPath = "outfitScrollArea.outfitList"
	self.dataPath = "outfitScrollArea.outfitList.%s"
	self.subWidgetPath = "outfitScrollArea.outfitList.%s.%s"
end

function outfitManager:load(key, class)
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
		local portrait = world.entityPortrait(player.id(), "bust")
		initTable.portrait = world.entityPortrait(player.id(), "head")

		status.removeEphemeralEffect("nude") 

		initTable.identity = getPlayerIdentity(portrait)
		initTable.npcType = "nakedvillager"
		initTable.podUuid = playerUuid
		self.playerParameters = copy(initTable)
		return self:addUnique("crew", crewmember, initTable)
	end
end

function outfitManager:setDisplayName(uId, displayName)
	if self.baseOutfit[uId] then
		self.baseOutfit[uId].displayName = displayName
	end
end

function outfitManager:getBaseOutfit(uId)
	return self.baseOutfit[uId]
end

function outfitManager:getWidgetPaths()
	return self.listPath, self.dataPath, self.subWidgetPath
end

function outfitManager:forEachElementInTable(tableName, func)
	for k,v in pairs(self[tableName]) do
		if func(v) then
			return
		end
	end
end

function outfitManager:getSelectedOutfit()
	local data = getSelectedListData(self.listPath)
	if data then
		return self:getBaseOutfit(data)
	end
end

function outfitManager:getTailorInfo(podUuid)
	local tailor = nil
	if podUuid then
		tailor = self.crew[podUuid]
	else
		self:forEachElementInTable("crew", function(recruit)
		    if recruit.npcType == "crewmembertailor" then
		    	tailor = recruit
		    	return true
		    end
		end)
	end
	if tailor then
		local uniqueId = tailor.uniqueId
		promises:add(world.sendEntityMessage(pane.containerEntityId(), "entityportrait", uniqueId, "bust"), setTailorPortrait)
		world.sendEntityMessage(pane.containerEntityId(), "blinkcrewmember", uniqueId, player.id())
	end
end

function setTailorPortrait(npcPort)
	dLogJson(npcPort, "npcPort")
	local portraits = config.getParameter("tailorPortraitNames")
	local num = 1
	while num <= #npcPort do
		widget.setImage(portraits[num], npcPort[num].image)
		widget.setVisible(portraits[num], true)
		num = num+1
	end
	while num <= #portraits do
		widget.setVisible(portraits[num], false)
		num = num+1
	end
end

function updatePortrait(crewId)
	crewId = crewId or player.uniqueId()
	local portraits = config.getParameter("portraitNames")
	local selectedOutfit = outfitManager:getSelectedOutfit() or {}
	local npc = outfitManager.crew[crewId] or outfitManager.crew[player.uniqueId{}]
	local num = 1
	local parameters = {}
	parameters.identity = npc.identity

	if selectedOutfit.items then
		parameters.items = crewutil.buildItemOverrideTable(crewutil.formatItemBag(self.itemSlot, selectedOutfit.items))
	end
	dLogJson(parameters, "updatePortrait: parameters", true)
	local npcPort = root.npcPortrait("full", npc.identity.species, "nakedvillager", 1, 1, parameters)

	while num <= #npcPort do
		widget.setImage(portraits[num], npcPort[num].image)
		widget.setVisible(portraits[num], true)
		num = num+1
	end
	while num <= #portraits do
		widget.setVisible(portraits[num], false)
		num = num+1
	end
end

function outfitSelected()
	local listPath, dataPath, subWidgetPath = outfitManager:getWidgetPaths()
	local data = getSelectedListData(listPath)

	dCompare("outfitSelected", listPath, data)
	
	world.containerTakeAll(pane.containerEntityId())
	local outfit = outfitManager:getBaseOutfit(data)
	if not outfit then
		local newItem = nil
		local hasUnsavedOutfit, outfitUuid = crewutil.subTableElementEqualsValue(outfitManager.baseOutfit, "displayName", "-- CHANGE ME --", "Uuid")
		if hasUnsavedOutfit then
			outfit = outfitManager:getBaseOutfit(outfitUuid)
			newItem = outfit.listItem
		else
			outfit = outfitManager:addUnique("baseOutfit", baseOutfit)
			newItem = widget.addListItem(listPath)
			outfit.listItem = newItem
		end
		widget.setText(subWidgetPath:format(newItem, "title"), outfit.displayName)
		widget.setData(dataPath:format(newItem), outfit.podUuid)
		dLogJson(outfit:toJson(),"NEW OUTFIT MADE:  ", true)
		return widget.setListSelected(listPath, newItem)
	end
	dLogJson(outfit:toJson(), "OUTFIT CHOSEN", true)
	widget.setText("tbOutfitName", outfit.displayName)
	widget.setData("btnAcceptOutfitName", outfit.podUuid)

	for i = 1, self.slotCount do
		local item = outfit.items[i]
		if item then
			world.containerItemApply(pane.containerEntityId(), item, i-1)
		end
	end

	return visibilityManager:setVisible("outfitRect", true)
end

function listOutfits(filter)
	local index = 2
	local listPath, dataPath, subWidgetPath = outfitManager:getWidgetPaths()
	widget.clearListItems(listPath)

	local newItem = widget.addListItem(listPath)
	widget.setText(subWidgetPath:format(newItem, "title"), "-- NEW --")
	widget.setData(dataPath:format(newItem), "-- NEW --")
	local sortedTable, keyTable = crewutil.sortedTablesByValue(outfitManager.baseOutfit, "displayName")
	if not (sortedTable and keyTable) then
	 	dCompare("nil sortedTable or keyTable", sortedTable, keyTable)
	 	return 
	end
	for i, outfitName in ipairs(sortedTable) do
		local outfitUuid = keyTable[outfitName]
		local outfit = outfitManager:getBaseOutfit(outfitUuid)

		if outfitName ~= "-- CHANGE ME --" then
			if outfitUuid and outfit then
				newItem = widget.addListItem(listPath)
				outfitManager:getBaseOutfit(outfitUuid).listItem = newItem
				widget.setText(subWidgetPath:format(newItem, "title"), outfit.displayName)
				widget.setData(dataPath:format(newItem), outfitUuid)
			end
		else
			outfitManager.baseOutfit[outfitUuid] = nil
		end
	end
end

function getPlayerIdentity(portrait)
	local self = {}
	self.species = player.species()
	self.gender = player.gender()
	self.name = world.entityName(player.id())
	
	
	local genderInfo = getAsset(getSpeciesPath(self.species, ":genders"))

	util.mapWithKeys(portrait, function(k,v)
	    local value = v.image:lower()

	    if value:find("malehead.png", 10, true) then
			self.personalityHeadOffset = v.position
		elseif value:find("arm.png",10, true) then
			self.personalityArmOffset = v.position
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
				self.hairGroup = partGroup
				self.hairType = partType
				self.hairDirectives = directive
				found = true 
			end
			for _,v in ipairs(genderInfo) do
				if found then break end
				for k,v in pairs(v) do
					if v == partGroup then
						self[k] = partGroup
						self[k:gsub("Group","Type")] = partType
						self[k:gsub("Group","Directives")] = directive
						found = true 
						break
					end
				end
			end
		end
	end

	self.personalityArmIdle = portrait[1].idle
	for k,v in ipairs(portrait) do
		local directory = v.directory
		if directory:find("malebody") then
			self.personalityIdle = v.idle
			self.bodyDirectives = v.directive
		elseif directory:find("emote") then
			self.emoteDirectives = v.directive
		end
	end
	return self
end

function checkForItemChanges(itemBag)
	local contentsChanged = false
    for i = 1, self.slotCount do
      if not compare(self.itemBagStorage[i], itemBag[i]) then
        if itemBag[i] ~= nil and (not inCorrectSlot(i, itemBag[i])) then
        	world.containerTakeAt(pane.containerEntityId(), i-1)
        	player.giveItem(itemBag[i])
        end
        contentsChanged = true
        break
      end
    end
    return contentsChanged
end

function inCorrectSlot(index, itemDescription)
  local success, itemType = pcall(root.itemType, itemDescription.name)
  if success then 
    if itemType == self.itemSlotType[index] then
      return true
    end
  end
  return false
end


function updateOutfitName(id, data)
	local outfitUuid = data or widget.getData(id)
	local listPath, dataPath, subWidgetPath = outfitManager:getWidgetPaths()
	local listItem = widget.getListSelected(listPath)
	local text = widget.getText("tbOutfitName") or "nil"
		dCompare("updateOutfitName", id, data)
		outfitManager:setDisplayName(outfitUuid, text)
		widget.setText(subWidgetPath:format(listItem, "title"), text)
end


function uninit()
	storage.baseOutfit = {}
	outfitManager:forEachElementInTable("baseOutfit", function(v)
		local json = v:toJson()
		storage.baseOutfit[v.podUuid] = json
	end)
	storage.crew = nil
	world.sendEntityMessage(pane.playerEntityId(), "wardrobeManager.setStorage", storage)
end