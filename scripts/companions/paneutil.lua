require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/scripts/messageutil.lua"

refreshManager, paneManager = {}, {}
refreshManager.__index = refreshManager
paneManager.__index = paneManager

List = {
	members = {

	}
}
List.__index = List

function List.new(...)
    local self = {}
    
    setmetatable(self, List)
    self:init(...)
    return self
end

function List:init(listConfig)
    self.items = {}
    self.itemIdByIndex = {}
	self.selectedItemId = -1
	self.listId = "outfitList"
    self.listPath = "outfitScrollArea.outfitList"
	self.listLayout = "layouts.outfitList"
	
	if type(listConfig) == "string" then
		listConfig = config.getParameter(listConfig)
	end
	if type(listConfig) == "table" then
		for k,v in pairs(listConfig) do
			self[k] = v
		end
	end
end

function List:item(id)
	return self.items[id or -1]
end

function List:itemAt(index)
	return self:item(self.itemIdByIndex[index])
end

function List:selectedItem()
    return self.items[self.selectedItemId]
end

function List:setSelectedItem(id)
    if not id then id = -1 end
    self.selectedItemId = id
end

function List:itemInstanceValue(id, jsonPath, default)
	local item = self:item(id)
    return sb.jsonQuery(item, jsonPath, default)
end

function List:addItem(data)
	local itemId = widget.addListItem(self.listPath)
	dLog(itemId)
	self.items[itemId] = data
	table.insert(self.itemIdByIndex, itemId)
end

function List:clearItems()
	widget.clearListItems(self.listPath)
	self.items = {}
	self.itemIdByIndex = {}
end

function List:removeItemAt()

end

function List:Each(func)
    for k,v in pairs(self.items) do
        if func(k,v) then
            return v,k
        end
    end
end


function getSpeciesPath(species, subPath)          
	return string.format("/species/%s.species%s",species,subPath)
end

--[[

==  paneManager ==

--]]
function paneManager.new(...)
	local self = setmetatable({}, paneManager)
	self:init(...)
	return self
end

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

function paneManager:getListSelected(key)
	local listPath = self.listPaths[key]
	return widget.getListSelected(listPath)
end

function paneManager:clearListItems(listPath)
	widget.clearListItems(listPath)
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
	for _,v in pairs(self.rects[key] or {}) do
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
			return path, (path.."."..listId), (path.."."..listId..".%s")
		end
		return path, path..".%s", path..".%s.%s"
	end
end

function paneManager:getPath(key, ...)
	local args = {...}
	local path = self.listPaths[key]
	table.insert(args, 1, path)
	return table.concat(args, ".")
end

function paneManager:getConfig(key, extra, default)
	local path = "paneManager."..key
	if extra then
		path = string.format("%s.%s", path, extra)
	end
	return config.getParameter(path, default)
end


function paneManager:setBaseData(listPath, itemPath, subWidgetPath, podUuid, newItem)
	local data = {}
	data.listItemId = newItem
	data.podUuid = podUuid
	data.listPath = listPath
	data.itemPath = itemPath
	data.subWidgetPath = subWidgetPath

	return data
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