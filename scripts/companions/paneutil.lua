require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/scripts/messageutil.lua"

refreshManager, paneManager = {}, {}
refreshManager.__index = refreshManager
paneManager.__index = paneManager

function getSpeciesPath(species, subPath)          
	return string.format("/species/%s.species%s",species,subPath)
end

--[[

==  paneManager ==

--]]

function paneManager:addListItem(listPath)
	local newItem = widget.addListItem(listPath)
	table.insert(self.listItems[listPath], newItem)
	return newItem
end

function paneManager:getListItemIndex(listPath, itemId)
	local output
	for i,v in pairs(self.listItems[listPath]) do
		if v == itemId then 
			output = i
			break
		end
	end
	return output
end

function paneManager:getListItemAtIndex(listPath, index)
	return self.listItems[listPath][index]
end

function paneManager:removeListItem(listPath, itemId)
	local index = self:getListItemIndex(listPath, itemId)
	widget.removeListItem(listPath, index-1)
	table.remove(self.listItems[listPath], index)
end

function paneManager:swapListItemSlots(listPath, firstItem, secondItem)

	local firstPosition = widget.getPosition(listPath.."."..firstItem)
	local secondPosition = widget.getPosition(listPath.."."..secondItem)
	dLogJson(firstPosition, "firstPosition")
	dLogJson(secondPosition, "secondPosition")

	

	local indexes = {}
	local value, i 
	value, indexes[1] = util.find(self.listItems[listPath], function(listId) return listId == firstItem end)
	value, indexes[2] = util.find(self.listItems[listPath], function(listId) return listId == secondItem end)

	table.sort(indexes)
	dLogJson(indexes, "INDEXES")
	table.remove(self.listItems[listPath], indexes[2])
	table.remove(self.listItems[listPath], indexes[1])
	table.insert(self.listItems[listPath], indexes[1], secondItem)
	table.insert(self.listItems[listPath], indexes[2], firstItem)

	widget.setPosition(listPath.."."..secondItem, firstPosition)
	widget.setPosition(listPath.."."..firstItem, secondPosition)
end

function paneManager:clearListItems(listPath)
	self.listItems[listPath] = {}
	-- body
end

function paneManager:init()
	local config = config.getParameter("paneManager")
	for k,v in pairs(config) do
		self[k] = v
  	end
end

function paneManager:setVisible(key, bool)
	for _,v in pairs(self:getConfig("rects",key)) do
		widget.setVisible(v, bool)
	end
end

function paneManager:setPortrait(npcPort, portraits)
	for num = 1, #npcPort do
		widget.setImage(portraits[num], npcPort[num].image)
		widget.setVisible(portraits[num], true)
	end

	for num = #npcPort+1, #portraits do
		widget.setVisible(portraits[num], false)
	end
end

function paneManager:getListPaths(key, listId)
	local path = self.listPaths[key]
	if path then
		if listId then
			return path, path.."."..listId, path.."."..listId..".%s"
		end
		return path, path..".%s", path..".%s.%s"
	end
end

function paneManager:getConfig(key, extra, default)
	local path = "paneManager."..key
	if extra then
		path = string.format("%s.%s", path, extra)
	end
	return config.getParameter(path, default)
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

function refreshManager:queue(key, func, force)
	if self:notQueued(key) or force then
		self.updateTable[key] = func
	end
end

function refreshManager:removeQueueItem(key)
	self.updateTable[key] = "skip"
end

function refreshManager:update()
	local updateTable = self.updateTable
	self.updateTable = {}
	for k,func in pairs(updateTable) do
		if type(func) == "function" then
			if func() then
				self:queue(k, func)
			end
		elseif type(func) == "table" then
			local args = func.args
			if func.unpack then
				if func.func(table.unpack(args)) then
					self:queue(k, func)
				end
			else
				if func.func(args) then
					self:queue(k, func)
				end
			end
		end
	end
end


function jsonPathExt(t, pathString)
	if t == nil then
		return pathString
	elseif type(pathString) == "string" then
		return path(t, table.unpack(util.split(pathString, ".")))
	end
end

function onOwnShip()
  return player.worldId() == player.ownShipWorldId()
end

function exchangeSlotItem(heldItem, slotItem, slotPath)
	player.setSwapSlotItem(slotItem)
	widget.setItemSlotItem(slotPath, heldItem)
end