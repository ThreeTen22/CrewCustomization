
Outfit = {}
Outfit.__index = Outfit
--[[

==  Outfit ==

--]]
function Outfit.new(...)
	local self = setmetatable({}, Outfit)
	self:init(...)
	return self
end

function Outfit:init(recruitUuId,storedOutfit)
	if storedOutfit then
		self.needsBuilding = false
		self.podUuid = recruitUuId
		self.items = storedOutfit.items
		self.name = storeOutfit.name
	else
		local recruit
		if recruitSpawner then
			recruit = recruitSpawner:getRecruit(recruitUuId)
        end
	end
end

function Outfit:buildOutfit(recruit)
	if recruitSpawner then
		recruit = recruitSpawner:getRecruit(recruit)
	else
		recruit = outfitManager.crew[recruit]
	end
	local items = {}
	local crewConfig, defaultUniform, colorIndex
	--get starting weapons
	local variant
	--dLogClass(recruit, "buildOutfit - recruit")
	if recruit.createVariant then
		variant = recruit:createVariant()
		crewConfig = root.npcConfig(recruit.spawnConfig.type).scriptConfig.crew or {}
	else
		variant = recruit:getVariant({})
		crewConfig = root.npcConfig(recruit.npcType).scriptConfig.crew or {}
	end
	for i, slot in ipairs(crewutil.weapSlots) do
		if variant.items[slot] then
			items[slot] = variant.items[slot].content
		end
	end
	--get starting outfit, building it due to FU not using the items override parameter
	if not isEmpty(crewConfig) then
		defaultUniform = crewConfig.defaultUniform
		colorIndex = crewConfig.role.uniformColorIndex
		for _,slot in ipairs(crewConfig.uniformSlots) do
			local item = defaultUniform[slot]
			if item then
				items[slot] = crewutil.dyeUniformItem(item, colorIndex)
			end
		end 
	end
	self.hasArmor, self.hasWeapons, self.emptyHands = crewutil.outfitCheck(items)
	self.items = crewutil.buildItemOverrideTable(crewutil.formatItemBag(items))
	self.planetTypes = {}
	for k,_ in pairs(wardrobeManager.planetTypes) do
		self.planetTypes[k] = true
	end

	self.name = "default"
end

function Outfit:toJson(skipTypes)
	local json = {}
	json.items = self.items
	json.hasArmor = self.hasArmor
	json.hasWeapons = self.hasWeapons
	json.emptyHands = self.emptyHands
	json.planetTypes = self.planetTypes
	json.name = self.name
	return json
end

function Outfit:overrideParams(parameters)
	local items = self.items
	parameters.items = items
	if path(parameters.scriptConfig,"initialStorage","crewUniform") then
		parameters.scriptConfig.initialStorage.crewUniform = {}
	end
	if path(parameters.scriptConfig,"initialStorage","itemSlots") then
		parameters.scriptConfig.initialStorage.itemSlots = nil
	end
	if path(parameters.scriptConfig,"crew","uniform") then
		parameters.scriptConfig.crew.uniform = {slots = {}}
	end
	setPath(parameters.scriptConfig, "behaviorConfig", "emptyHands", self.emptyHands)

	return parameters
end