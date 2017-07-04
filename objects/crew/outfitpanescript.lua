require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/scripts/messageutil.lua"
require "/scripts/companions/wardrobeclasses.lua"
require "/scripts/companions/crewutil.lua"
require "/scripts/companions/paneutil.lua"

function init()
	storage = {}
	self.itemBagStorage = {}
	self.reloadingList = false
	self.outfitListCoroutine = nil
	paneManager:init()
	outfitManager:init()
	refreshManager:init()

	widget.registerMemberCallback("outfitScrollArea.outfitList", "setTitle", setTitle)
	widget.registerMemberCallback("outfitScrollArea.outfitList", "unfocusWidget", function(id,data) return widget.blur(data.path) end)
	widget.registerMemberCallback("outfitScrollArea.outfitList", "deleteOutfit", deleteOutfit)
	widget.registerMemberCallback("outfitScrollArea.outfitList", "slotSelected", function(id,data) return slotSelected(id,data, true) end)
	widget.registerMemberCallback("outfitScrollArea.outfitList", "slotSelectedRight", function(id,data) return slotSelected(id,data, false) end)

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
	storage.baseOutfit = args.baseOutfit or {}
	storage.crew = args.crew or {}
	dLogJson(storage.crew, "STORAGE CREW")
	storage.wardrobes = args.wardrobes or {}

	
	outfitManager:load("crew", Crewmember)
	outfitManager:load("baseOutfit", baseOutfit)
	outfitManager:loadPlayer(2)
	local tailor = outfitManager:getTailorInfo()
	if tailor then
		promises:add(world.sendEntityMessage(player.id(), "wardrobeManager.getOutfit", tailor.podUuid), 
		    		function(outfit) 
		    			paneManager:setPortrait(tailor:getPortrait("bust", outfit.items), config.getParameter("tailorRect"))
		    		end)
	end
	wardrobeManager:init()
	listOutfits()
	update = updateMain
end

function updateMain()
	promises:update()
	timer.tick(dt)
	refreshManager:update()
end

function outfitSelected(id, data)
	if self.clearingList == true then return end
end

function newOutfit(id, data)
	outfit = outfitManager:addUnique("baseOutfit", baseOutfit)
	local listPath, _, subWidgetPath = paneManager:getListPaths("outfitList")
	self.reloadingList = true

	local newItem = paneManager:addListItem(listPath)
	setOutfitListItemInfo(newItem, outfit.podUuid)
	widget.focus(subWidgetPath:format(newItem, "title"))
	self.reloadingList = false
end

function listOutfits(filter)
	self.reloadingList = true
	
	filter = filter or {}
	local listPath, itemPath, subWidgetPath = paneManager:getListPaths("outfitList")
	local sortedRefTable = {}
	local newItem, sortedKeys = "", {}

	

	
	util.each(outfitManager.baseOutfit, 
	function(podUuid, outfit, output)  
		if isEmpty(filter) then output = podUuid end  
		for k,v in pairs(filter) do
			if outfit[k]:find(v,1,true) then
				output = podUuid
			else
				output = nil
			end
		end

		table.insert(sortedKeys, output)

	end)
	table.sort(sortedKeys, function(i,j) return outfitManager:getBaseOutfit(i).displayName < outfitManager:getBaseOutfit(j).displayName end)

	dLogJson(sortedKeys, "sortedKeysAfter: ")
	--sortedKeys = util.map(displayIds, 
	--function(podUuid)
	--	local outfit = outfitManager:getBaseOutfit(podUuid)
	--	local uniqueDisplayName = outfit.displayName..podUuid:sub(1,3)
	--	sortedRefTable[uniqueDisplayName] = podUuid
	--	return uniqueDisplayName
	--end)
	--table.sort(sortedKeys)
	--dLogJson(displayIds, "sortedKeys: ")
	--displayIds = {}
	--for _,v in ipairs(sortedKeys) do
	--	table.insert(displayIds, sortedRefTable[v])
	--end
	--dLogJson(displayIds, "displayIds2: ")
	paneManager:clearListItems(listPath)

	for _,podUuid in ipairs(sortedKeys) do
		newItem = paneManager:addListItem(listPath)
		setOutfitListItemInfo(newItem, podUuid)
	end
	self.reloadingList = false
end

function setOutfitListItemInfo(newItem, podUuid)
	local listPath, itemPath, subWidgetPath = paneManager:getListPaths("outfitList", newItem)
	local data = {}
	local baseOutfit = outfitManager:getBaseOutfit(podUuid)
	data.listItemId = newItem
	data.podUuid = podUuid
	data.listPath = listPath
	data.itemPath = itemPath
	data.subWidgetPath = subWidgetPath

	widget.setData(data.itemPath, data)

	
	data.path = data.subWidgetPath:format("title")
	widget.setText(data.path, baseOutfit.displayName)
	widget.setData(data.path, data)

	data.path = data.subWidgetPath:format("btnDelete")
	widget.setData(data.path, data)

	widget.setText(data.subWidgetPath:format("listNumber"), tostring(paneManager:getListItemIndex(data.listPath, data.listItemId)))

	for k, v in pairs(crewutil.itemSlots) do
		data.path = data.subWidgetPath:format("itemSlotRect."..v)
		widget.setData(data.path, data)
		widget.setItemSlotItem(data.path, baseOutfit.items[v])
	end
	return refreshManager:queue(data.listItemId, {func = updateListItemPortrait, args = data})
end

function deleteOutfit(id, data)
	local output = {}
	for k,v in pairs(outfitManager.baseOutfit) do
		output[k] = v.podUuid
	end
	local items = outfitManager:getBaseOutfit(data.podUuid).items
	for k, v in pairs(items) do
		if k and v then
			player.giveItem(v)
		end
	end
	outfitManager:deleteOutfit(data.podUuid)

	return paneManager:removeListItem(data.listPath, data.listItemId)
end	


function slotSelected(id, data, doExchange)
	if doExchange then
		exchangeSlotItem(player.swapSlotItem(), widget.itemSlotItem(data.path), data.path)
	else
		player.giveItem(widget.itemSlotItem(data.path))
		widget.setItemSlotItem(data.path, nil)
	end
	outfitManager:getBaseOutfit(data.podUuid).items[id] = widget.itemSlotItem(data.path)
	updateListItemPortrait(data)
end

function updateListItemPortrait(data)
	local outfit = outfitManager:getBaseOutfit(data.podUuid)
	local npcPort = outfitManager.crew[player.uniqueId()]:getPortrait("full", crewutil.buildItemOverrideTable(crewutil.formatItemBag(outfit.items, false)))
	npcPort = crewutil.portraitToMannequin(npcPort)
	
	local portraitRect = config.getParameter("portraitRect")
	for i,v in ipairs(portraitRect) do
		portraitRect[i] = data.subWidgetPath:format(v)
	end
	return paneManager:setPortrait(npcPort, portraitRect)
end


function setTitle(id, data)
	if not self.reloadingList then
		local text = widget.getText(data.path)
		outfitManager:setDisplayName(data.podUuid, text)
	end
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

function uninit()
	storage.baseOutfit = {}
	outfitManager:forEachElementInTable("baseOutfit", function(v)                        
		if not isEmpty(v.items) then
			if v.displayName == "" then 
				v.displayName = v.podUuid:sub(1, 6)
			end
			storage.baseOutfit[v.podUuid] = v:toJson()   
		end
	end)
	storage.crew = nil

	--world.sendEntityMessage(player.id(), "wardrobeManager.setStorage", storage)
    world.sendEntityMessage(pane.sourceEntity(), "recruit.confirmUnfollow")
end
