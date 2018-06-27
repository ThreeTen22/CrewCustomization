--require "/scripts/npcspawnutil.lua"
--I GOT PLANS BABY...I GOT PLANS

require "/scripts/companions/crewutil.lua"
require "/scripts/companions/wardrobeclasses.lua"




--Essentially the vanilla spawn parameters, gutted some parameter sets due to irrelevency
function Recruit:prepareSpawnParameters()
	local parameters = {}
	util.mergeTable(parameters, self.spawnConfig.parameters)
	local scriptConfig = self:_scriptConfig(parameters)
	parameters.persistent = self.persistent
	scriptConfig.initialStatus = copy(self.status) or {}
	scriptConfig.initialStorage = util.mergeTable(scriptConfig.initialStorage or {}, self.storage or {})

	local spawnOutfit = wardrobeManager:getOutfit(self.podUuid)
	if spawnOutfit and (not isEmpty(spawnOutfit)) then
		spawnOutfit:overrideParams(parameters)
	end
	return parameters
end
	


function Recruit:_spawn(position, parameters)
	local parameters = self:prepareSpawnParameters()

	sb.logInfo(sb.printJson(parameters, 1))
	return world.spawnNpc(position, self.spawnConfig.species,  self.spawnConfig.type, parameters.level, self.spawnConfig.seed, parameters)
end

function Recruit:createVariant()
	local parameters = self:prepareSpawnParameters()
	return root.npcVariant(self.spawnConfig.species, self.spawnConfig.type, parameters.level, self.spawnConfig.seed, parameters)
end



function Recruit:createPortrait(portraitType)
	local parameters = self:prepareSpawnParameters()
	return root.npcPortrait(portraitType, self.spawnConfig.species, self.spawnConfig.type, parameters.level, self.spawnConfig.seed, parameters)
end


--MODIFIED FROM scripts/companions/player.lua
---Intercepting in order to show outfit management GUI, without needing to directly modify the tailor in any capacity.

function offerUniformUpdate(recruitUuid, entityId)
	local recruit = recruitSpawner:getRecruit(recruitUuid)
	if not recruit then return end
	player.interact("ScriptPane", "/objects/crew/outfitpanedelegate.config", entityId)

	promises:add(world.sendEntityMessage(entityId, "recruit.confirmFollow", true))
end


oldInitCE = init
function init()	
  	oldInitCE()
	clearStorage({"wardrobe", "crew", "outfit"})
	Outfits:init()
	Outfits:load("outfit", Outfit)
	return wardrobeManager:init()
end

oldUninitCE = uninit
function uninit()
	wardrobeManager:storeWardrobes()
	return oldUninitCE()
end