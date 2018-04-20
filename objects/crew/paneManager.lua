paneManager = {
    configDirectory = "/objects/crew/outfitpane.config"
}
paneManager.__index = paneManager

function paneManager.new(path)
    local self = setmetaTable({}, paneManager)
    paneManager:init(path)
    return self
end

function paneManager:init(path)
    self.listPath = path
    local subWidgets = root.assetJson(self.configDirectory..':'..path)
    
end

function paneManager:addListItem()
	local newItem = widget.addListItem(self.listPath)
	table.insert(self.listItems[self.listPath], newItem)
	return newItem
end

function paneManager:getListItemIndex(itemId)
	local output
	for i,v in pairs(self.listItems[self.listPath]) do
		if v == itemId then 
			output = i
			break
		end
	end
	return output
end

function paneManager:getListItemAtIndex(index)
	return self.listItems[self.listPath][index]
end

function paneManager:removeListItem(self.listPath, itemId)
	local index = self:getListItemIndex(self.listPath, itemId)
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
