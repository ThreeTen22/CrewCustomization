require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/scripts/messageutil.lua"

outfitManager, baseOutfit, crewmember, refreshManager, paneManager = {}, {}, {}, {}, {}
outfitManager.__index = outfitManager
baseOutfit.__index = baseOutfit
crewmember.__index = crewmember
refreshManager.__index = refreshManager
paneManager.__index = paneManager

function getSpeciesPath(species, subPath)          
    return string.format("/species/%s.species%s",species,subPath)
end

function getSelectedListData(listPath)
  local itemId = widget.getListSelected(listPath)
  if itemId then
    local fullpath = string.format("%s.%s", listPath, itemId)
    return widget.getData(fullpath)
  end
end


--[[

==  paneManager ==

--]]

function paneManager:init()
  local config = config.getParameter("paneManager")
  local str = "paneManager.%s"
  for k,_ in pairs(config) do
    self[k] = str:format(k).."%s"
  end
end

function paneManager:setVisible(key, bool)
  for _,v in pairs(self:getConfig("rects",key,{})) do
    widget.setVisible(v, bool)
  end
end

function paneManager:setPortrait(npcPort, portraits)
  for num = 1, #npcPort do
    widget.setImage(portraits[num], npcPort[num].image)
    widget.setVisible(portraits[num], true)
  end

  for num = #npcPort, #portraits do
    widget.setVisible(portraits[num], false)
  end
end

function paneManager:setTailorPortrait(npcPort)
  local portraits = config.getParameter("tailorPortraitNames")
  return self:setPortrait(npcPort, portraits)
end

function paneManager:getListPaths(key)
  local path = self:getConfig(self.listPaths, key, nil)
  if path then
    return path, path..".%s", path..".%s.%s"
  end
end

function paneManager:getConfig(key, extra, default)
  if extra then
    if string.sub(extra, 1, 1) ~= "." then extra = "."..extra end
  else 
    extra = ""
  end
  local path = self[key]..extra
  return config.getParameter(path, default)
end

function paneManager:batchSet(configKey, t)
  local widgetNames = self:getConfig("batchSet",configKey, {})
  for k,v in pairs(widgetNames) do
    widget[v[1]](k, t[v[2]])
  end
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

function refreshManager:queue(key, func)
  if self:notQueued(key) then
    self.updateTable[key] = func
  end
end

function refreshManager:update()
  local updateTable = self.updateTable
  self.updateTable = {}
  for _,func in pairs(updateTable) do
    if type(func) == "function" then
      func()
    elseif type(func) == "table" then
      local args = func.args
      if func.unpack then
        func.func(table.unpack(args))
      else
        func.func(args)
      end
    end
  end
  -- body
end

--[[

==  crewmember ==

--]]

function crewmember.new(...)
  local self = setmetatable({},crewmember)
  self:init(...)
  return self
end

function crewmember:init(stored)
  self.podUuid = stored.podUuid
  self.npcType = stored.npcType
  self.identity = stored.identity
  self.portrait = stored.portrait
  self.uniqueId = stored.uniqueId
  self.type = "crewmember"
end

function crewmember:toJson()
  local json = {
    podUuid = self.podUuid
    npcType = self.npcType
    identity = self.identity
    portrait = self.portrait
    uniqueId = self.uniqueId
  }
  return json
end

function crewmember:getPortrait(portraitType, naked)
  local parameters = {identity = self.identity}

  return root.npcPortrait(portraitType, self.identity.species, self.npcType, 1, 1, parameters)
end

--[[

==  baseOutfit ==

--]]

function baseOutfit.new(...)
  local self = setmetatable({},baseOutfit)
  self:init(...)
  return self
end

function baseOutfit:init(stored)
  stored = stored or {}
  self.items = stored.items or {}
  self.podUuid = stored.podUuid or sb.makeUuid()
  self.displayName = stored.displayName or "-- CHANGE ME --"
  self.listItem = nil
  self.type = "baseOutfit"
end

function baseOutfit:toJson()
  local json = {}
  json.items = self.items
  json.podUuid = self.podUuid
  json.displayName = self.displayName
  return json
end


function baseOutfit:set( ... )
  -- body
end

--[[

==  outfitManager ==

--]]

function outfitManager:init(...)
  self.crew = {}
  self.baseOutfit = {}
  self.widgetItems = {}
  self.playerParameters = nil
  self.listPath = "outfitScrollArea.outfitList"
  self.dataPath = "outfitScrollArea.outfitList.%s"
  self.subWidgetPath = "outfitScrollArea.outfitList.%s.%s"
end

function outfitManager:load(key, class)
  for k,v in pairs(storage[key]) do
    self[key][k] = class.new(v)
  end
end

function outfitManager:addUnique(key, class, storedValue)
  local newClass = class.new(storedValue)
  local uId = newClass.podUuid
  self[key][uId] = newClass
  return self[key][uId]
end

function outfitManager:loadPlayer(step)
  if step == 1 then
    status.addEphemeralEffect("nude", 5.0)
  elseif step == 2 then
    local initTable = {}
    local playerUuid = player.uniqueId() 
    local bustPort = world.entityPortrait(player.id(), "bust")
    initTable.portrait = world.entityPortrait(player.id(), "head")

    status.removeEphemeralEffect("nude") 

    initTable.identity = crewutil.getPlayerIdentity bustPort)
    initTable.npcType = "nakedvillager"
    initTable.podUuid = playerUuid
    self.playerParameters = copy(initTable)
    return self:addUnique("crew", crewmember, initTable)
  end
end

function outfitManager:setDisplayName(uId, displayName)
  if self.baseOutfit[uId] then
    self.baseOutfit[uId].displayName = displayName
  end
end

function outfitManager:getBaseOutfit(podUuid)
  return self.baseOutfit[podUuid]
end

function outfitManager:getWidgetPaths()
  return self.listPath, self.dataPath, self.subWidgetPath
end

function outfitManager:forEachElementInTable(tableName, func)
  for k,v in pairs(self[tableName]) do
    if func(v) then
      return
    end
  end
end

function outfitManager:getSelectedOutfit()
  local data = getSelectedListData(self.listPath)
  if data then
    return self:getBaseOutfit(data)
  end
end

function outfitManager:deleteOutfit(uId)
  if uId then
    self.baseOutfit[uId] = nil
  end
end

function outfitManager:deleteSelectedOutfit()
  local data = getSelectedListData(self.listPath)
  return self:deleteOutfit(data)
end

function outfitManager:getTailorInfo(podUuid)
  local tailor = nil
  if podUuid then
    tailor = self.crew[podUuid]
  else
    self:forEachElementInTable("crew", function(recruit)
        if recruit.npcType == "crewmembertailor" then
          tailor = recruit
          return true
        end
    end)
  end
  return tailor
end
