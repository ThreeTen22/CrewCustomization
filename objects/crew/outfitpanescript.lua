require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/scripts/messageutil.lua"
require "/scripts/companions/crewutil.lua"


local function getSpeciesPath(species, subPath)          
    return string.format("/species/%s.species%s",path,species)
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
	self.player = nil
	self.itemBag = nil
	self.itemBagStorage = nil
	promises:add(world.sendEntityMessage(pane.playerEntityId(), "wardrobeManager.getStorage"), setupOutfits)
	return
end

function update(dt)
	--updatePortrait()
	promises:update()
	timer.tick(dt)
	return 
end

function updatePortrait()
  local num = 1
  local portraits = config.getParameter("portraitNames")
  local npcPort = root.npcPortrait("full", "human", "villager", 1)
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
	self.species = player.species()
	self.identity = getPlayerIdentity(self.species, player.gender())
end

function getPlayerIdentity(species, gender)
	local self = {}
	--local genderPath = ":genders.0"
	--if gender == "female" then genderPath = ":genders.1" end
	--local success, genderTable = getAsset(getSpeciesPath(player.species(), genderPath))
	--if success then
	--self.hairGroup = genderTable.hairGroup or "hair"
	--self.
	--end
	-- body
	
	local portrait = world.entityPortrait(player.id(), "head")
	portrait = crewutil.newArrayFromKey(portrait, "image")
	dLogJson(portrait, "portrait")
end
