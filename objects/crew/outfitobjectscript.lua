require "/scripts/npcspawnutil.lua"
function init()
	return
end

function die()
	world.containerTakeAll(entity.id())
end