require "/scripts/util.lua"
require "/scripts/interp.lua"
require "/scripts/messageutil.lua"
require "/scripts/companions/crewutil.lua"

local function logContents(args)
	dLog("Pane: logging Contents: ")
	for k,v in pairs(args) do
		dLogJson(v, k, true)
	end
end

function init()
	self.itemBag = nil
	self.itemBagStorage = nil
	promises:add(world.sendEntityMessage(pane.playerEntityId(), "wardrobeManager.getWardrobes"), logContents)
	return
end

function update(dt)
	updatePortrait()
	promises:update()
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
