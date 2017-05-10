require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/scripts/messageutil.lua"
require "/scripts/companions/crewutil.lua"


local function getSpeciesPath(species, subPath)          
    return string.format("/species/%s.species%s",species,subPath)
 end

function setupOutfits(args)
	dLog("Pane: logging Contents: ")
	storage.wardrobes = args.wardrobes
	storage.baseOutfits = args.baseOutfits
	if not storage.player then
		timer.start(0.10, getPlayerInfo)
		status.addEphemeralEffect("nude", 1, player.id())
	end
end

function init()
	if not storage then storage = {} end
	self.playerIdentity = nil
	self.itemBag = nil
	self.itemBagStorage = nil
	self.dirty = false
	promises:add(world.sendEntityMessage(pane.playerEntityId(), "wardrobeManager.getStorage"), setupOutfits)
	return
end

function update(dt)
	promises:update()
	timer.tick(dt)
	return 
end

function updatePortrait()
	local identity = self.playerIdentity or {species = "human"}
	local portraits = config.getParameter("portraitNames")
	local npcPort = root.npcPortrait("full", identity.species, "nakedvillager", 1, math.random(1,24353458), {identity = identity})
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


function getPlayerInfo()
	local portrait = world.entityPortrait(player.id(), "bust")
	status.removeEphemeralEffect("nude")
	self.playerIdentity = getPlayerIdentity(player.species(), player.gender(), portrait)
	timer.start(0.01, updatePortrait)
end

function getPlayerIdentity(species, gender, portrait)
	local self = {}
	self.gender = gender
	self.species = species
	--BEING DEBUG--
	--portrait = root.npcPortrait("bust", "avian", "nakedvillager", 1, math.random(1, 5348854093), {identity = {gender = self.gender}})
	--self.species = "avian"
	--END DEBUG--
	local _, genderInfo = getAsset(getSpeciesPath(self.species, ":genders"))

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
				self.hairDirectives = v.directive
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
