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
	paneManager:init()
	outfitManager:init()
	refreshManager:init()

	widget.registerMemberCallback("outfitScrollArea.outfitList", "setTitle", setTitle)
	widget.registerMemberCallback("outfitScrollArea.outfitList", "deleteOutfit", deleteOutfit)
	widget.registerMemberCallback("outfitScrollArea.outfitList", "slotSelected", slotSelected)
	widget.registerMemberCallback("outfitScrollArea.outfitList", "slotSelectedRight", slotSelectedRight)

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
	dLogJson(args, "initExtended", true)
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
	local listPath, _, _ = paneManager:getListPaths("outfitList")
	self.reloadingList = true
	local newItem = widget.addListItem(listPath)
	dLog(newItem.podUuid,  "newOutfitPod")
	setOutfitListItemInfo(newItem, outfit.podUuid)
	self.reloadingList = false
end

function listOutfits(filter)
	filter = filter or {}
	local listPath, itemPath, subWidgetPath = paneManager:getListPaths("outfitList")
	self.reloadingList = true
	widget.clearListItems(listPath)

	local displayIds = util.map(outfitManager.baseOutfit, 
	function(outfit, output)  
		if isEmpty(filter) then output = outfit.podUuid end  
		for k,v in pairs(filter) do
			if outfit[k]:find(v,1,true) then
				output = outfit.podUuid
				break
			end
		end
		return output
	end)
	for _,podUuid in pairs(displayIds) do
		local newItem = widget.addListItem(listPath)
		setOutfitListItemInfo(newItem, podUuid)
	end
	self.reloadingList = false
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


function setOutfitListItemInfo(newItem, podUuid)
	local listPath, itemPath, subWidgetPath = paneManager:getListPaths("outfitList")
	local data = {}
	local baseOutfit = outfitManager:getBaseOutfit(podUuid)
	data.listItemId = newItem
	data.podUuid = podUuid
	data.listPath = listPath
	data.itemPath = listPath.."."..newItem
	data.subWidgetPath = data.itemPath..".%s"

	widget.setData(data.itemPath, data)

	
	data.path = data.subWidgetPath:format("title")
	widget.setText(data.path, baseOutfit.displayName)

	widget.setData(data.path, data)
	data.path = data.subWidgetPath:format("btnDelete")
	widget.setData(data.path, data)
	for k, v in pairs(crewutil.itemSlots) do
		data.path = data.subWidgetPath:format("itemSlotRect."..v)
		widget.setData(data.path, data)
		widget.setItemSlotItem(data.path, baseOutfit.items[v])
		updateListItemPortrait(data)
	end
end

function deleteOutfit(id, data)
	local output = {}
	for k,v in pairs(outfitManager.baseOutfit) do
		output[k] = v.podUuid
	end
	local items = outfitManager:getBaseOutfit(data.podUuid).items
	dLogJson(items, "deleteOutfit - ITEMS")
	for k, v in pairs(items) do
		if k and v then
			player.giveItem(v)
		end
	end
	outfitManager:deleteOutfit(data.podUuid)
	return refreshManager:queue("listOutfits", listOutfits)
end	


function slotSelected(id, data)
	exchangeSlotItem(player.swapSlotItem(), widget.itemSlotItem(data.path), data.path)
	outfitManager:getBaseOutfit(data.podUuid).items[id] = widget.itemSlotItem(data.path)

	updateListItemPortrait(data)
end

function slotSelectedRight(id,data)
	player.giveItem(widget.itemSlotItem(data.path))
	widget.setItemSlotItem(data.path, nil)
	outfitManager:getBaseOutfit(data.podUuid).items[id] = widget.itemSlotItem(data.path)
	updateListItemPortrait(data)
end

function updateListItemPortrait(data)
	local outfit = outfitManager:getBaseOutfit(data.podUuid)
	local npcPort = outfitManager.crew[player.uniqueId()]:getPortrait("full", crewutil.buildItemOverrideTable(crewutil.formatItemBag(outfit.items, false)))
	
	local portraitRect = config.getParameter("portraitRect")
	for i,v in ipairs(portraitRect) do
		portraitRect[i] = data.subWidgetPath:format(v)
	end
	return paneManager:setPortrait(npcPort, portraitRect)
end

function exchangeSlotItem(heldItem, slotItem, slotPath)
	dLogJson({heldItem, slotItem, slotPath}, "exchangeSlotItem", true)
	player.setSwapSlotItem(slotItem)
	widget.setItemSlotItem(slotPath, heldItem)
end

function setTitle(id, data)
	if not self.reloadingList then
		local text = widget.getText(data.path)
		local default = config.getParameter("baseOutfit.displayName")
		local otherDefault = default:sub(1, -2)
		text = gMatchPlain(text, default, "")
		text = gMatchPlain(text, otherDefault, "")
		widget.setText(data.path, text)
		outfitManager:setDisplayName(data.podUuid, text)
	end
end

function uninit()
	storage.baseOutfit = {}
	local baseDisplayName = config.getParameter("baseOutfit.displayName")
	outfitManager:forEachElementInTable("baseOutfit", function(v)
	    if (not isEmpty(v.items) ) or v.displayName ~= baseDisplayName then                          
			if v.displayName == baseDisplayName or v.displayName == "" then 
				v.displayName = v.podUuid:sub(1, 6)
			end
			storage.baseOutfit[v.podUuid] = v:toJson()   
		end
		
	end)
	storage.crew = nil

	world.sendEntityMessage(player.id(), "wardrobeManager.setStorage", storage)
    world.sendEntityMessage(pane.sourceEntity(), "recruit.confirmUnfollow")
end
