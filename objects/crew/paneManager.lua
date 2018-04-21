require "/scripts/companions/crewutil.lua"

paneManager = {}
paneManager.__index = paneManager

function paneManager.new(path)
    local self = setmetatable({}, paneManager)
    paneManager:init(path)
    return self
end


function paneManager:init(path)
	self.layout = path

	local config = config.getParameter("gui."..path..".data")
	assert(config, "bad config path:  "..path)

	self.title = config.title
	self.scrollArea = config.scrollArea
	self.list = config.list
	self.portraitCount = config.portraitCount
	self.listSubWidgets = config.listSubWidgets
	self.listItems = {}
	self.listItemPaths = {}
	dLogJson(config)
	dLog(self.list)
	dLog(self.title)
end

function paneManager:addListItem()
	local newItem = widget.addListItem(self.list)
	table.insert(self.listItems, newItem)

	self.listItemPaths[newItem] = {
		title = self.listSubWidgets.title:format(newItem),
		background = self.listSubWidgets.background:format(newItem)
	}
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
	widget.removeListItem(self.list, index-1)
	table.remove(self.listItems, index)
end

function paneManager:getListSelected()
	return widget.getListSelected(self.list)
end

function paneManager:clearListItems()
	self.listItems = {}
	self.listItemPaths = {}
	return widget.clearListItems(self.list)
	
	-- body
end

function paneManager:setVisible(key, subkey)
	return false
end

function paneManager:setItemTitle(listItem, title)
	dLogJson(self.listItemPaths[listItem], "listItem, paths: ")
	local path = self.listItemPaths[listItem].title
	return widget.setText(path, title)
end



function paneManager:setPortrait(npcPort, listItem)
	local portraitPaths = {}
	
	if listItem then
		for i=1, self.portraitCount do
			table.insert(portraitPaths, self.listSubWidgets.portrait:format(listItem, i))
		end
	else
		for i=1, self.portraitCount do
			table.insert(portraitPaths, self.portrait:format(i))
		end
	end

	local npcPortCount = #npcPort
	for num = 1, npcPortCount do
		widget.setImage(portraitPaths[num], npcPort[num].image)
		widget.setVisible(portraitPaths[num], true)
	end

	for num = npcPortCount+1, self.portraitCount do
		widget.setVisible(portraitPaths[num], false)
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

function paneManager:debugOutput()
	local done = {}
	for k,v in ipairs(self) do
		if done[k] == k then break; end
		if type(v) ~= 'function' and type(v)~= 'nil' then
			done[k] = v
		end
	end
	sb.logInfo(self.layout)
	sb.logJson(done, 1)
end
