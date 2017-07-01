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
	dLogJson("updateInit", args, true)
	storage.baseOutfit = args.baseOutfit or {}
	storage.crew = args.crew or {}

	outfitManager:loadPlayer(2)
	outfitManager:load("crew", crewmember)
	outfitManager:load("baseOutfit", baseOutfit)
	local tailor = outfitManager:getTailorInfo()
	if tailor then
		paneManager:setPortrait(tailor:getPortrait("bust"), config.getParameter("tailorRect"))
    	--promises:add(world.sendEntityMessage(pane.sourceEntity(), "entityportrait", tailor.uniqueId, "bust"),function(v) ) end)
    	--world.sendEntityMessage(pane.sourceEntity(), "blinkcrewmember", tailor.uniqueId, player.id())
	end
	
	listOutfits()
	--updateOutfitPortrait()

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
	outfit.displayName = outfit.podUuid:sub(1, 6)
	return refreshManager:queue("listOutfits", listOutfits)
end

function listOutfits(filter)
	filter = filter or {}
	local listPath, itemPath, subWidgetPath = paneManager:getListPaths("outfitList")
	self.clearingList = true
	widget.clearListItems(listPath)
	self.clearingList = false

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
		local data = {}
		local baseOutfit = outfitManager:getBaseOutfit(podUuid)
		data.listItemId = newItem
		data.podUuid = podUuid
		data.basePath = itemPath:format(newItem)
		widget.setData(data.basePath, data)
		
		widget.setText(subWidgetPath:format(newItem, "title"), "-- NEW --")


		

		local itemSlotPath = nil
		for k, v in pairs(crewutil.itemSlots) do
			data.path = listPath.."."..newItem.."."..v
			dLogJson(data, "itemSlotData")
			widget.setData(data.path, data)
			widget.setItemSlotItem(data.path, baseOutfit.items[v])
			updateListItemPortrait(data)
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
	local outfitUuid =  data.podUuid
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
	local _,_, subWidgetPath = paneManager:getListPaths("outfitList")
	local outfit = outfitManager:getBaseOutfit(data.podUuid)

	local npcPort = outfitManager.crew[player.uniqueId()]:getPortrait("full", crewutil.buildItemOverrideTable(crewutil.formatItemBag(outfit.items, false)))
	
	local portraitRect = config.getParameter("portraitRect")
	for i,v in ipairs(portraitRect) do
		portraitRect[i] = data.basePath.."."..v
	end
	dLogJson(npcPort, "npcPort")
	dLogJson(portraitRect, "updateListItemPortrait")
	return paneManager:setPortrait(npcPort, portraitRect)
end

function exchangeSlotItem(heldItem, slotItem, slotPath)
	dLogJson({heldItem, slotItem, slotPath}, "exchangeSlotItem", true)
	player.setSwapSlotItem(slotItem)
	widget.setItemSlotItem(slotPath, heldItem)
end