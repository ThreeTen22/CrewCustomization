require "/scripts/npcspawnutil.lua"
function init()
	return
end

function update(dt)
	return
end

function onInteraction(args)
	dLog("hit!")
	return {"ScriptPane", config.getParameter("uiConfig")}
end