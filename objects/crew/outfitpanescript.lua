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
	self.pane = paneManager.new()
	self.outfits = List.new()
	self.bgCanvas = widget.bindCanvas("cvsBackground")
	refreshManager:init()

	widget.registerMemberCallback("outfitScrollArea.outfitList", "setTitle", setTitle)
	widget.registerMemberCallback("outfitScrollArea.outfitList", "unfocusWidget", function(id,data) return widget.blur(data.path) end)
	widget.registerMemberCallback("outfitScrollArea.outfitList", "deleteOutfit", deleteOutfit)

	widget.registerMemberCallback("outfitScrollArea.outfitList", "expandItem", expandItem)
	--[[
		As a pane menu is both local and not considered an entity in and of itself,  the message will run syncronously. 
		(Referencing how world.findUniqueEntity() is exploited to quickly determine a player's existance in the world)
	]]
	local outfits = msgSelf("wardrobe.getOutfits"):result()
	local list = self.pane:getPath("outfitList")

	--dLogJson(outfits, "in pane")
	for k,v in pairs(outfits) do 
		self.outfits:addItem(v)
	end

	for i=0, 10 do
		widget.addListItem(list)
	end
end

do
	function update(dt)
		promises:update()
		timer.tick(dt)
		refreshManager:update()
	end

	function dismissed()
		world.sendEntityMessage(pane.sourceEntity(), "recruit.confirmUnfollow", true)
	end

end

do

	function setTitle(id, d)
		if widget.hasFocus(d.path) then
			local text = widget.getText(d.path)
			self.pane:setDisplayName(d.podUuid, text)
		end
	end

	function deleteOutfit(id, data)

	end

	function expandItem(id, data)
		local path = data.."."..widget.getListSelected(data)
		dLog(path)
		widget.setSize(path, {250, 100})
	end

	function msgSelf(msg, ...)
		return world.sendEntityMessage(player.id(), msg, ...)
	end

	function msgSource(msg, ...)
		return world.sendEntityMessage(pane.sourceEntity(), msg, ...)
	end
end

--[[
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
	listCrewmembers()

	--paneManager:setVisible("wardrobeRect", false)
	--paneManager:setVisible("baseOutfitRect", true)

	--update = updateMain
end

function updateMain(dt)
	promises:update()
	timer.tick(dt)
	refreshManager:update()
end

function outfitSelected(id, data)
	if self.clearingList == true then return end
end

function newOutfit(id, data)
	self.reloadingList = true
	local listPath, itemPath, subWidgetPath = paneManager:getListPaths("outfitList")
	paneManager:clearListItems(listPath)
	local outfit = outfitManager:addUnique("baseOutfit", baseOutfit)
	listOutfits()
	self.reloadingList = false
end

function listCrewmembers()
	self.reloadingList = true
	local listPath, _, _ = paneManager:getListPaths("wardrobeList")
	local newItem

	--paneManager:clearListItems(listPath)
	for podUuid, crewmember in pairs(outfitManager.crew) do
		newItem = paneManager:addListItem(listPath) 
		setWardrobeListItemData(newItem, podUuid)
	end
	self.reloadingList = false
end

function setWardrobeListItemData(newItem, podUuid)
	local listPath, itemPath, subWidgetPath = paneManager:getListPaths("wardrobeList", newItem)
	local data = {}

	data.podUuid = podUuid

	widget.setData(data.itemPath, data)

	data.path = data.subWidgetPath:format("title")
	widget.setText(data.path, outfitManager:getCrewmember(podUuid).identity.name)
	widget.setData(data.path, data)
end

function crewmemberSelected(id, data)
	local listPath, dataPath, subWidgetPath = paneManager:getListPaths("wardrobeList")
	data = widget.getData(dataPath:format(paneManager:getListSelected("wardrobeList")))

	self.reloadingList = true
	
	
	listPath, dataPath, subWidgetPath  = paneManager:getListPaths("wardrobeDetailList")
	paneManager:clearListItems(listPath)

	for planet, outfitKey in pairs(outfitMap) do
		local newItem = paneManager:addListItem(listPath)
		wardrobeDetailItemData(data.podUuid, newItem, itemKey)
	end
	
	self.reloadingList = false
	return paneManager:setVisible("wardrobeRect", true)
	-- body
end

function wardrobeDetailItemData(podUuid, newItem, outfitKey)
		local wardrobe = wardrobeManager.wardrobes[data.podUuid].outfits[outfitKey]
		local outfitMap = wardrobe.outfitMap

		local data = paneManager:setBaseData(paneManager:getListPaths("wardrobeDetailList", newItem), podUuid, newItem)

		data.outfitKey = outfitKey

		data.path = subWidgetPath:format("title")
		widget.setText(data.path, crewutil.getCelestialBiomeNames(planet))
		widget.setData(data.path, data)
		data.path = subWidgetPath:format("baseOutfitButton")
		widget.setText(data.path, outfitKey)
		widget.setData(data.path, data)
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
	--paneManager:clearListItems(listPath)
	for _,podUuid in ipairs(sortedKeys) do
		newItem = paneManager:addListItem(listPath)
		setOutfitListItemData(newItem, podUuid)
		if outfitManager:getBaseOutfit(podUuid).displayName == "" then
			local itemId = subWidgetPath:format(newItem, "title")
			refreshManager:queue("setFocus", function() widget.focus(itemId) end, true)
		end
	end
	self.reloadingList = false
end

function setOutfitListItemData(newItem, podUuid)
	local baseOutfit = outfitManager:getBaseOutfit(podUuid)
	local data = paneManager:setBaseData(paneManager:getListPaths("outfitList", newItem), podUuid, newItem)

	widget.setData(data.itemPath, data)

	data.path = data.subWidgetPath:format("title")
	widget.setText(data.path, baseOutfit.displayName)
	widget.setData(data.path, data)

	data.path = data.subWidgetPath:format("btnDelete")
	widget.setData(data.path, data)
	local text = data.subWidgetPath:format("listNumber"), paneManager:getListItemIndex(data.listPath, data.listItemId);
	widget.setText()

	for k, v in pairs(crewutil.itemSlots) do
		data.path = data.subWidgetPath:format("itemSlotRect."..v)
		widget.setData(data.path, data)
		widget.setItemSlotItem(data.path, baseOutfit.items[v])
	end
	return refreshManager:queue(data.listItemId, {func = updateListItemPortrait, args = data})
end


function changeOufit(id, data)
	local position = widget.getPosition(data.path)
	return true
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
	dLog(data.listItemId, "deletingOutfit: ")
	return paneManager:removeListItem(data.listPath, data.listItemId)
end	


function slotSelected(id, data, doExchange)
	if player.swapSlotItem() == widget.itemSlotItem(data.path) then return end
	if doExchange then
		exchangeSlotItem(player.swapSlotItem(), widget.itemSlotItem(data.path), data.path)
	else
		player.giveItem(widget.itemSlotItem(data.path))
		widget.setItemSlotItem(data.path, nil)
	end
	outfitManager:getBaseOutfit(data.podUuid).items[id] = widget.itemSlotItem(data.path)

	return refreshManager:queue(data.listItemId, {func = updateListItemPortrait, args = data})
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
    world.sendEntityMessage(pane.sourceEntity(), "recruit.confirmUnfollow", true)
end

--]]