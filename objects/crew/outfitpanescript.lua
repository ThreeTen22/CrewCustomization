require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/scripts/messageutil.lua"
require "/scripts/companions/crewutil.lua"

--[[NOTES:
	timer can be manipulated to use coroutines.  give coroutine as function,  pass coroutine in as variable
--]]
outfitManager, baseOutfit, crewmember, refreshManager = {}, {}, {}, {}
outfitManager.__index = outfitManager
baseOutfit.__index = baseOutfit
crewmember.__index = crewmember
refreshManager.__index = refreshManager

--[[

==  LOCAL FUNCTIONS ==
(Will not display in _ENV)

--]]
local function getSpeciesPath(species, subPath)          
    return string.format("/species/%s.species%s",species,subPath)
end

local function loadPlayerPartTwo()
	refreshManager:queue("listOutfits", listOutfits)
	refreshManager:queue("refreshPortrait", updatePortrait)
	return outfitManager:loadPlayer(2)
end


function init()
	if not storage then storage = {} end
	self.itemBag = nil
	self.itemBagStorage = nil
	self.outfitFilter = nil
	outfitManager:init()
	refreshManager:init()
	promises:add(world.sendEntityMessage(pane.playerEntityId(), "wardrobeManager.getStorage"), setupOutfits)
	return
end


function update(dt)
	promises:update()
	timer.tick(dt)
	refreshManager:update()
	return 
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
			func.func(args)
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
	self.Uuid = stored.podUuId
	self.npcType = stored.npcType
	self.identity = stored.identity
	self.portrait = stored.portrait
end

function crewmember:getPortrait(portraitType)
	return root.npcPortrait(portraitType, self.identity.species, self.npcType, 1, 1, {identity = self.identity})
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
	self.Uuid = stored.Uuid or ""
	self.displayName = stored.displayName or "init"
end

--[[

==  outfitManager ==

--]]

function outfitManager:init(...)
	self.crew = {}
	self.baseOutfit = {}
	self.selectedOutfit = ""
end

function outfitManager:load(key, class)
	for k,v in pairs(storage[key]) do
		self[key][k] = class.new(v)
	end
end

function outfitManager:addUnique(key, uniqueId, class, storedValue)
	self[key][uniqueId] = class.new(storedValue)
end

function outfitManager:loadPlayer(step)
	if step == 1 then
		status.addEphemeralEffect("nude", 5.0)
		timer.start(0.1, loadPlayerPartTwo)
	elseif step == 2 then
		local initTable = {}
		local playerUuid = player.uniqueId() 
		local portrait = world.entityPortrait(player.id(), "bust")
		initTable.portrait = world.entityPortrait(player.id(), "head")

		status.removeEphemeralEffect("nude") 

		initTable.identity = getPlayerIdentity(portrait)
		initTable.npcType = "nakedvillager"
		initTable.UuId = playerUuid
		self.playerIdentity = copy(initTable)
		return self:addUnique("crew", playerUuid, crewmember, initTable)
	end

end

function setupOutfits(args)
	dLog("Pane: logging Contents: ")
	storage.baseOutfit = args.baseOutfit or {}
	storage.crew = args.crew or {}

	outfitManager:load("crew", crewmember)
	outfitManager:load("baseOutfit", baseOutfit)
	if not outfitManager.baseOutfit then outfitManager.baseOutfit = {} end
	if not outfitManager.crew then outfitManager.crew = {} end

	return outfitManager:loadPlayer(1)
end

function updatePortrait()
	local identity = outfitManager.playerIdentity or {species = "human"}
	local portraits = config.getParameter("portraitNames")
	local npcPort = root.npcPortrait("full", identity.identity.species, "nakedvillager", 1, math.random(1,24353458), identity)
	local num = 1
	while num <= #npcPort do
		widget.setImage(portraits[num], npcPort[num].image)
		widget.setVisible(portraits[num], true)
		num = num+1
	end
	while num <= #portraits do
		widget.setVisible(portraits[num], false)
		num = num+1
	end
end

function outfitSelected()

	return
end

function queueRefresh( ... )
	-- body
end

function listOutfits(filter)
	local index = 2
	local dataPath = "outfitScrollArea.outfitList.%s"
	local subWidgetPath = "outfitScrollArea.outfitList.%s.%s"
	
	local newItem = widget.addListItem("outfitScrollArea.outfitList")
	widget.setText(subWidgetPath:format(newItem, "title"), "-- NEW --")
	local sortedTable, keyTable = crewutil.sortedTablesByValue(outfitManager.baseOutfit, "displayName")
	if not (sortedTable and keyTable) then return end
	for i, outfitName in ipairs(sortedTable) do
		local outfitUuid = keyTable[outfitName]
		local outfit = outfitManager[key]
		if uuid and outfit then
			newItem = widget.addListItem("outfitScrollArea.outfitList")
			widget.setData(dataPath:format(newItem), outfitUuid)
		end
	end
end

function getPlayerIdentity(portrait)
	local self = {}
	self.species = player.species()
	self.gender = player.gender()
	self.name = world.entityName(player.id())
	
	
	local genderInfo = getAsset(getSpeciesPath(self.species, ":genders"))

	util.mapWithKeys(portrait, function(k,v)
	    local value = v.image:lower()

	    if value:find("malehead.png", 10, true) then
			self.personalityHeadOffset = v.position
		elseif value:find("arm.png",10, true) then
			self.personalityArmOffset = v.position
		end

	    value = value:match("/humanoid/.-/(.-)%?addmask=.*")
	    local directory, idle, directive = value:match("(.+)%.png:(.-)(%?.+)")

		return {directory = directory, idle = idle, directive = directive}
	end, portrait)

	

	for k,v in ipairs(portrait) do
		local found = false
		local directory = v.directory
		local directive = v.directive
		if directory:find("/") then
			local partGroup, partType = directory:match("(.-)/(.+)")
			if partGroup == "hair" then
				self.hairGroup = partGroup
				self.hairType = partType
				self.hairDirectives = directive
				found = true 
			end
			for _,v in ipairs(genderInfo) do
				if found then break end
				for k,v in pairs(v) do
					if v == partGroup then
						local key = k 
						self[k] = partGroup
						self[k:gsub("Group","Type")] = partType
						self[k:gsub("Group","Directives")] = directive
						found = true 
						break
					end
				end
			end
		end
	end

	self.personalityArmIdle = portrait[1].idle
	for k,v in ipairs(portrait) do
		local directory = v.directory
		if directory:find("malebody") then
			self.personalityIdle = v.idle
			self.bodyDirectives = v.directive
		elseif directory:find("emote") then
			self.emoteDirectives = v.directive
		end
	end
	return self

end

function checkForItemChanges(itemBag, contentsChanged)
    for i = 1, self.slotCount do
      if not compare(self.equipBagStorage[i], itemBag[i]) then
        if itemBag[i] ~= nil and (not inCorrectSlot(i, itemBag[i])) then
        	if promises:empty() then
            	promises:add(world.sendEntityMessage(pane.containerEntityId(), "removeItemAt", i), player.giveItem(itemBag[i]))
        	else
        		return
        	end
        end
        if not (self.items.override) then
          self.items.override = npcUtil.buildItemOverrideTable(self.items.override)
        end
        local insertPosition = self.items.override[1][2][1]
        --Add items to override item slot so they update visually.
        setItemOverride(self.equipSlot[i], insertPosition, itemBag[i])
        contentsChanged = true
      end
    end

    if contentsChanged then 
      if npcUtil.isContainerEmpty(itemBag) then
        self.items.override = nil
      end
    end
    self.equipBagStorage = widget.itemGridItems("itemGrid") 
    return contentsChanged
end


function updateOutfitName()
	outfitManager:addUnique("baseOutfit", tostring(math.random(1,1000)), baseOutfit, {displayName = tostring(math.random(1,1000))})
	return listOutfits()
end
