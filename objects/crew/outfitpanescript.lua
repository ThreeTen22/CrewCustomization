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
	paneManager:init()
	outfitManager:loadPlayer(1)
	promises:add(world.sendEntityMessage(pane.playerEntityId(), "wardrobeManager.getStorage"), initExtended)
	return
end

function update(dt)
	promises:update()
	timer.tick(dt)
	refreshManager:update()
end

function initExtended(args)
	dLogJson("updateInit", args, true)
	storage.baseOutfit = args.baseOutfit or {}
	storage.crew = args.crew or {}

	outfitManager:loadPlayer(2)
	outfitManager:load("crew", crewmember)
	outfitManager:load("baseOutfit", baseOutfit)
	local tailor = outfitManager:getTailorInfo()
	if tailor then
    	promises:add(world.sendEntityMessage(pane.containerEntityId(), "entityportrait", tailor.uniqueId, "bust"),function(v) paneManager:setTailorPortrait(v) end)
    	world.sendEntityMessage(pane.containerEntityId(), "blinkcrewmember", tailor.uniqueId, player.id())
	end
	
	listOutfits()
	updateOutfitPortrait()

	update = updateMain
end

function updateMain()
	local itemBag = widget.itemGridItems("itemGrid")
	if checkForItemChanges(itemBag) then
		local outfit = outfitManager:getSelectedOutfit()
		if outfit then
			outfit.items = itemBag
			refreshManager:queue("updateOutfitPortrait", updateOutfitPortrait)
		end
		
	end
	self.itemBagStorage = widget.itemGridItems("itemGrid")
	promises:update()
	timer.tick(dt)
	refreshManager:update()
	return 
end


function updateOutfitPortrait(crewId)
	crewId = crewId or player.uniqueId()
	local selectedOutfit = outfitManager:getSelectedOutfit() or {}
	local npc = outfitManager.crew[crewId] or outfitManager.crew[player.uniqueId{}]
	local parameters = {}
	parameters.identity = npc.identity

	if selectedOutfit.items then
		parameters.items = crewutil.buildItemOverrideTable(crewutil.formatItemBag(crewutil.itemSlots, selectedOutfit.items))
	end
	dLogJson(parameters, "updateOutfitPortrait: parameters", true)
	local npcPort = root.npcPortrait("full", npc.identity.species, "nakedvillager", 1, 1, parameters)
	paneManager:setPortrait(npcPort, config.getParameter("portraitNames"))
end

function outfitSelected()
	if self.clearingList then return end
	local listPath, dataPath, subWidgetPath = paneManager:getListPaths("outfitList")
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
	paneManager:batchSet("outfitRect", outfit)
	--widget.setText("tbOutfitName", outfit.displayName)
	--widget.setData("btnAcceptOutfitName", outfit.podUuid)
	--widget.setData("btnDeleteOutfit", outfit.podUuid)
	for i = 1, #crewutil.itemSlots do
		local item = outfit.items[i]
		if item then
			world.containerItemApply(pane.containerEntityId(), item, i-1)
		end
	end
	refreshManager:queue("updateOutfitPortrait", updateOutfitPortrait)
	return paneManager:setVisible("outfitRect", true)
end

function listOutfits(filter)
	local index = 2
	local listPath, dataPath, subWidgetPath = paneManager:getListPaths("outfitList")
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

function checkForItemChanges(itemBag)
	local contentsChanged = false
    for i = 1, #crewutil.itemSlots do
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
	local listPath, dataPath, subWidgetPath = paneManager:getListPaths("outfitList")
	local listItem = widget.getListSelected(listPath)
	local text = widget.getText("tbOutfitName") or "nil"
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
	paneManager:setVisible("outfitRect", false)
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