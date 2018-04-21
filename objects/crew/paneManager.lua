paneManager = {}
paneManager.__index = paneManager

function paneManager.new(path)
    local self = setmetaTable({}, paneManager)
    paneManager:init(path)
    return self
end

function paneManager:init(path)
	self.layout = path
	self.listItems = {}
	self.listPath = self.layout..".scrollArea.list"
end

function paneManager:addListItem()
	local newItem = widget.addListItem(self.listPath)
	table.insert(self.listItems, newItem)
	return newItem
end

function paneManager:getListItemIndex(itemId)
	local output
	for i,v in pairs(self.listItems) do
		if v == itemId then 
			output = i
			break
		end
	end
	return output
end

function paneManager:getListItemAtIndex(index)
	return self.listItems[index]
end

function paneManager:removeListItem(itemId)
	local index = self:getListItemIndex(itemId)
	widget.removeListItem(self.listPath, index-1)
	table.remove(self.listItems[self.listPath], index)
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
