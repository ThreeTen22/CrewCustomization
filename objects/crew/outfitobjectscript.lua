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
--[[
Getting npcs to stay off the loungables long enough to teleport them is damn near impossible

While calling init twice is silly, its the only damn way to do it as npc.resetlounging() doesn't override the behavior of lounging, behavior has its own set of position variables,
and if there is an inconsistancy between the two during lounging then it will default to the behavior position and just teleport you.
which is what really needs to happen.  Init is the only real way to do it.  At least the vanilla tailor doesn't have any "actual" follow or quest behaviors

--start: locks the function just in case of multiple calls. 
--first timer : init used to get off the damn lounagble,  seems to take a few frames before it actually is off the loungable.
--second timer:  actually moves and freezes the npc for 30 seconds to mock "merchant" behavior.
--third timer: unlocks the function and resets this object's update delta to 0
--end: sets update delta to every frame for the duration of this "effect"
--]]
function blinkInCrewmember(uniqueId, playerId)
	local crewId = world.loadUniqueEntity(uniqueId)
	if not self.blinkingIn then	
		self.blinkingIn = true
		--world.sendEntityMessage(crewId, "applyStatusEffect", "paralysis", 5)
		world.callScriptedEntity(crewId, "init")
		world.sendEntityMessage(crewId, "applyStatusEffect", "blink")
		
		self.timer.start(0.2, function()  world.callScriptedEntity(crewId, "init") end)
		self.timer.start(0.25, function()
		                local position = entity.position()
		                local playerPosition = world.entityPosition(playerId)
		                position[2] = playerPosition[2]
		                world.callScriptedEntity(crewId, "mcontroller.setPosition", position)
		                world.callScriptedEntity(crewId, "init")
		                world.callScriptedEntity(crewId, "npc.setAimPosition", playerPosition)
		                world.callScriptedEntity(crewId, "status.setResource", "stunned", 30)
		            end)
		self.timer.start(0.5, function()
		                self.blinkingIn = false
					    script.setUpdateDelta(0)
					end)
		script.setUpdateDelta(1)
	end
end