--require "/scripts/npcspawnutil.lua"
--I GOT PLANS BABY...I GOT PLANS
local oldInitCE = init
function init()
  require "/scripts/crewutil.lua"
  dLog("modArmor Companions Init")
  logENV()
  return oldInitCE()
end

Recruit._oldSpawnCE = Recruit._spawn
function Recruit._spawn(asSelf, position, parameters)
	dLog("spawning Recruit")
	dLogJson(asSelf:toJson(), "selfALL", true)
	local items = path(asSelf.spawnConfig, "scriptConfig","personality","storedOverrides", "items")
	local override = nil
	if not items then
		items = buildItemOverrideTable()
		override = items.override[1][2][1]
		for k,v in pairs(asSelf.storage.itemSlots) do
			if v then
				override[k] = {}
				table.insert(override[k], v)
			end
		end
	else
		override = path(items,"override",1,2,1)
	end
	if override and ((override.primary or override.alt) and (override.sheathedprimary or override.sheathedalt)) then
		setPath(parameters.scriptConfig, "behaviorConfig", "emptyHands", false)
	end
	parameters.items = items
	setPath(parameters.scriptConfig,"crew","uniformSlots",jobject())
	local returnValue = asSelf:_oldSpawnCE(position, parameters)
	return returnValue
end

function buildItemOverrideTable()
	local items = {}
	local container = nil
	items.override = {}

	table.insert(items.override, {})
	container = items.override[1]
	table.insert(container, 0)
	table.insert(container, {})
	container = items.override[1][2]
	table.insert(container, {})
	return items
end

