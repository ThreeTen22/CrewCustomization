--require "/scripts/npcspawnutil.lua"
--I GOT PLANS BABY...I GOT PLANS
local oldInitCompanionsExtended = init
function init()
  require "/scripts/npcspawnutil.lua"
  dLog("companions Init")
  local returnData = oldInitCompanionsExtended()
  return returnData
end

Recruit._oldSpawnCompanionsExtended = Recruit._spawn

function Recruit._spawn(asSelf, position, parameters)
	dLog("spawning Recruit")
	--dLogJson(asSelf.spawnConfig, "selfSpawnConfig", true)
	dLogJson(asSelf.storage, "selfALL", true)
	local items = buildItemOverrideTable()
	local override = items.override[1][2][1]
	for k,v in pairs(asSelf.storage.itemSlots) do
		if v then
			override[k] = {}
			table.insert(override[k], v)
		end
	end
	dLogJson(items, "spawnedItems", true)
	parameters.items = items
	asSelf:_oldSpawnCompanionsExtended(position, parameters)
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

