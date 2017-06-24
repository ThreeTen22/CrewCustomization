require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/scripts/messageutil.lua"
require "/scripts/companions/crewutil.lua"
require "/scripts/companions/paneutil.lua"

function init()
	if not storage then storage = {} end
	self.itemBagStorage = {}
	self.clearingList = false
	paneManager:init()
	outfitManager:init()
	refreshManager:init()
	
	widget.registerMemberCallback("outfitScrollArea.outfitList", "listSlotSelected", listSlotSelected)

	outfitManager:loadPlayer(1)
	promises:add(world.sendEntityMessage(player.id(), "wardrobeManager.getStorage"), initExtended)
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
    	promises:add(world.sendEntityMessage(pane.sourceEntity(), "entityportrait", tailor.uniqueId, "bust"),function(v) paneManager:setPortrait(v, "tailorRect") end)
    	world.sendEntityMessage(pane.sourceEntity(), "blinkcrewmember", tailor.uniqueId, player.id())
	end
	
	listOutfits()
	updateOutfitPortrait()

	update = updateMain
end

function updateMain()
	promises:update()
	timer.tick(dt)
	refreshManager:update()
end


function updateOutfitPortrait(crewId)
	crewId = crewId or player.uniqueId()
	local selectedOutfit = outfitManager:getSelectedOutfit() or {}
	local npc = outfitManager.crew[crewId] or outfitManager.crew[player.uniqueId{}]
	local parameters = {}
	parameters.identity = npc.identity

	if selectedOutfit.items then
		parameters.items = crewutil.buildItemOverrideTable(crewutil.formatItemBag(crewutil.itemSlots, selectedOutfit.items, true))
	end
	dLogJson(parameters, "updateOutfitPortrait: parameters", true)
	local npcPort = root.npcPortrait("full", npc.identity.species, "nakedvillager", 1, 1, parameters)
	paneManager:setPortrait(npcPort, "portraitRect")
end

function outfitSelected(id, data)
	if self.clearingList == true then return end
	local listPath, dataPath, subWidgetPath = paneManager:getListPaths("outfitList")
	local data = paneManager:getSelectedListData("outfitList")
	dCompare("outfitSelected", listPath, data)
	
	paneManager:batchSetWidgets("clearOutfitItemSlots")
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
			widget.setData(subWidgetPath:format(newItem, "itemSlot"), subWidgetPath:format(newItem, "itemSlot"))
			outfit.listItem = newItem
		end
		widget.setText(subWidgetPath:format(newItem, "title"), outfit.displayName)
		widget.setData(dataPath:format(newItem), outfit.podUuid)
		return widget.setListSelected(listPath, newItem)
	end

	paneManager:batchSetWidgets("outfitRect", outfit)

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
				
				dLog(subWidgetPath:format(newItem, "itemSlot"),"subWidgetPath: ")
				widget.setData(subWidgetPath:format(newItem, "itemSlot"), subWidgetPath:format(newItem, "itemSlot"))
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
        	world.containerTakeAt(pane.sourceEntity(), i-1)
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
    if itemType == crewutil.itemSlotType[index] then
      return true
    end
  end
  return false
end


function updateOutfitName(id, data)
	local outfitUuid =  data or widget.getData(id)
	local listPath, dataPath, subWidgetPath = paneManager:getListPaths("outfitList")
	local listItem = widget.getListSelected(listPath)
	local text = widget.getText("tbOutfitName") or "nil"
		outfitManager:setDisplayName(outfitUuid, text)
		widget.setText(subWidgetPath:format(listItem, "title"), text)
end

function deleteOutfit()
	local items = paneManager:batchGetWidgets("outfitItemSlotItems")

	dLogJson(items, "deleteOutfit - ITEMS")
	for k, v in pairs(items) do
		if k and v then
			player.giveItem(v)
		end
	end
	paneManager:batchSetWidgets("clearOutfitItemSlots")
	outfitManager:deleteSelectedOutfit()
	paneManager:setVisible("outfitRect", false)
	refreshManager:queue("listOutfits", listOutfits)
end	


function uninit()
	storage.baseOutfit = {}
	outfitManager:forEachElementInTable("baseOutfit", function(v)
		if v.displayName == "-- CHANGE ME --" and isEmpty(v.items) == false then 
			local name = v.podUuid
			local min = math.random(1,name:len()-10)
			v.displayName = name:sub(min,min+10)
		end
		storage.baseOutfit[v.podUuid] = v:toJson()
	end)
	storage.crew = nil
	world.sendEntityMessage(player.id(), "wardrobeManager.setStorage", storage)
end

function slotSelected(id, data)
	dLogJson({id, data}, "slotSelected")
	exchangeSlotItem(player.swapSlotItem(), widget.itemSlotItem(data), data)
end

function exchangeSlotItem(heldItem, slotItem, slotPath)
	dLogJson({heldItem, slotItem, slotPath}, "exchangeSlotItem", true)
	player.setSwapSlotItem(slotItem)
	widget.setItemSlotItem(slotPath, heldItem)
end

function listSlotSelected(id, data)
	dLogJson({id, data}, "listSlotSelected")
	exchangeSlotItem(player.swapSlotItem(), widget.itemSlotItem(data), data)
	local outfit = outfitManager:getSelectedOutfit()
	outfit.items = paneManager:batchGetWidgets("outfitItemSlotItems")
end