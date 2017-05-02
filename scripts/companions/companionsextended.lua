--require "/scripts/npcspawnutil.lua"
--I GOT PLANS BABY...I GOT PLANS

outfit = {}
outfit.__index = outfit

function outfit.new(...)
  local self = setmetatable({}, outfit)
  self:init(...)
  return self
end

function outfit:init(json)
end


outfitManager = {}

function outfitManager:init()
	for uuid, follower in (recruitSpawner.followers) do
		dCompare("outfitManager init", uuid, follower)
	end
end


function outfitManager:update(dt)
	dLog("outfitManager: updating")
	return false
end
outfitManager.finished = outfitManager.update

local oldInitCE = init
function init()
  local returnValue = oldInitCE()
  outfitManager:init()
  return returnValue
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

