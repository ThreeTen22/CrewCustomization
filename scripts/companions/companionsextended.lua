--require "/scripts/npcspawnutil.lua"
--I GOT PLANS BABY...I GOT PLANS
local oldInitCE = init
function init()
  require "/scripts/companions/crewutil.lua"
  dLog("modArmor Companions Init")
  return oldInitCE()
end

Recruit._oldSpawnCE = Recruit._spawn
function Recruit:_spawn(position, parameters)
	local items = path(self.spawnConfig.parameters,"scriptConfig","personality","storedOverrides","items","override",1,2,1) or {}
	local hasArmor = false
	local hasWeapons = false
	hasArmor, hasWeapons = crewutil.outfitCheck(items)
	local shouldEquip = crewutil.buildEquipTable(not hasArmor, not hasWeapons)
	for k,v in pairs(self.storage.itemSlots) do
		if v and shouldEquip[k] then
			items[k] = {}
			table.insert(items[k], v)
		end
	end	
	local itemTable = crewutil.buildItemOverrideTable(items)
	
	if (items.primary or items.alt) and (items.sheathedprimary or items.sheathedalt) then
		setPath(parameters.scriptConfig, "behaviorConfig", "emptyHands", false)
	end
	parameters.items = itemTable
	setPath(parameters.scriptConfig,"initialStorage","itemSlots", {})
	if hasArmor then
		setPath(parameters.scriptConfig,"crew","uniformSlots",{})
	end
	if hasArmor or hasWeapons then
		setPath(self.spawnConfig.parameters,"scriptConfig","personality","storedOverrides","items",itemTable)
	end
	self:_oldSpawnCE(position, parameters)
	self.spawner:markDirty()
end

