require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/scripts/messageutil.lua"
require "/scripts/companions/crewutil.lua"
require "/scripts/companions/paneutil.lua"

function init()
	if not storage then storage = {} end
	self = config.getParameter("initVars")
	self.itemBagStorage = widget.itemGridItems("itemGrid")
	self.clearingList = false
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
	local tailor = outfitManager:getTailorInfo()
	if tailor then
    	promises:add(world.sendEntityMessage(pane.containerEntityId(), "entityportrait", tailor.uniqueId, "bust"), setTailorPortrait)
    	world.sendEntityMessage(pane.containerEntityId(), "blinkcrewmember", tailor.uniqueId, player.id())
	end
	
	listOutfits()
	updatePortrait()

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
	if self.clearingList then return end
	local listPath, dataPath, subWidgetPath = outfitManager:getWidgetPaths()
	local data = getSelectedListData(listPath)
	dCompare("outfitSelected", listPath, data)
	
	world.containerTakeAll(pane.containerEntityId())
	local outfit = outfitManager:getBaseOutfit(data)
	if not outfit then
		local newItem = nil
		local hasUnsavedOutfit, outfitUuid = crewutil.subTableElementEqualsValue(outfitManager.baseOutfit, "displayName", "-- CHANGE ME --", "podUuid")
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
	refreshManager:queue("updatePortrait", updatePortrait)
	return visibilityManager:setVisible("outfitRect", true)
end

function listOutfits(filter)
	local index = 2
	local listPath, dataPath, subWidgetPath = outfitManager:getWidgetPaths()
	self.clearingList = true
	widget.clearListItems(listPath)
	local newItem = widget.addListItem(listPath)
	widget.setText(subWidgetPath:format(newItem, "title"), "-- NEW --")
	widget.setData(dataPath:format(newItem), "-- NEW --")
	local sortedTable, keyTable = crewutil.sortedTablesByValue(outfitManager.baseOutfit, "displayName")
	self.clearingList = false
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

function deleteOutfit()
	local items = widget.itemGridItems("itemGrid")
	dLogJson(items, "deleteOutfit - ITEMS")
	for k, v in pairs(items) do
		if k and v then
			player.giveItem(v)
		end
	end
	world.containerTakeAll(pane.containerEntityId())
	outfitManager:deleteSelectedOutfit()
	visibilityManager:setVisible("outfitRect", false)
	refreshManager:queue("listOutfits", listOutfits)
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