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
function paneManager:init()
	local config = config.getParameter("paneManager")
	local str = "paneManager.%s"
	for k,v in pairs(config) do
		self[k] = str:format(k)
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

function paneManager:getListPaths(key)
	local path = self:getConfig("listPaths", key, nil)
	if path then
		return path, path..".%s", path..".%s.%s"
	end
end

function paneManager:getConfig(key, extra, default)
	local path = self[key] or ""
	if extra then
		path = string.format("%s.%s", path, extra)
	end
	return config.getParameter(path, default)
end

function paneManager:batchSetWidgets(configKey, t)
	local widgetNames = self:getConfig("batchSet",configKey, {})
	for k,v in pairs(widgetNames) do
		for i = 1, #v, 2 do
			widget[v[i]](k, jsonPathExt(t, v[i+1]))
		end
	end
end

function paneManager:getSelectedListData(listName)
	local path = self:getConfig("listPaths", listName, "")
	local itemId = widget.getListSelected(path)
	if itemId then
		path = string.format("%s.%s", path, itemId)
	end
	dLog(path, "getSelectedListData")
	return widget.getData(path)
end


function paneManager:batchGetWidgets(configKey)
	local widgetNames = self:getConfig("batchGet",configKey, {})
	local output = {}
	for k,v in pairs(widgetNames) do
		if v[2] ~= "table" then
			output[k] = widget[v[1]](v[2])
		else
			output[k] = widget[v[1]](table.unpack(v[2]))
		end
	end
	return output
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