require "/scripts/util.lua"
require "/scripts/messageutil.lua"
require "/npcs/timers.lua"
require "/scripts/companions/crewutil.lua"


function init()
	self.timer = createTimers()
	self.blinkingIn = false
	message.setHandler("entityportrait", simpleHandler(entityPortrait))
	message.setHandler("blinkcrewmember", simpleHandler(blinkInCrewmember))
	return
end

function update(dt)
	self.timer.tick(dt)
end

function die()
	world.containerTakeAll(entity.id())
end

function entityPortrait(uniqueId, portraitType)
	local crewId = world.loadUniqueEntity(uniqueId)
	local portrait = world.entityPortrait(crewId, portraitType)
	return portrait
end

function blinkInCrewmember(uniqueId, playerId)
	local crewId = world.loadUniqueEntity(uniqueId)
	if not self.blinkingIn then	
		self.blinkingIn = true
		--world.sendEntityMessage(crewId, "applyStatusEffect", "paralysis", 5) 
		world.callScriptedEntity(crewId, "init")
		world.sendEntityMessage(crewId, "applyStatusEffect", "blink") 
		self.timer.start(0.25, function()
		                local position = entity.position()
		                local playerPosition = world.entityPosition(playerId)
		                position[2] = playerPosition[2]
		                world.callScriptedEntity(crewId, "mcontroller.setPosition", position)
		            end)
		self.timer.start(0.5, function()
		                self.blinkingIn = false
					    script.setUpdateDelta(0)
					end)
		script.setUpdateDelta(1)
	end
end