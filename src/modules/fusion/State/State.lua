--[[
	Constructs and returns objects which can be used to model independent
	reactive state.
]]

local initDependency = UIX.Require:import(__FUSION_SRC_PATH__('/Dependencies/initDependency.lua'))
local useDependency = UIX.Require:import(__FUSION_SRC_PATH__('/Dependencies/useDependency.lua'))
local updateAll = UIX.Require:import(__FUSION_SRC_PATH__('/Dependencies/updateAll.lua'))

local class = {}

local CLASS_METATABLE = {__index = class}
local WEAK_KEYS_METATABLE = {__mode = "k"}

--[[
	Returns the value currently stored in this State object.
	The state object will be registered as a dependency unless `asDependency` is
	false.
]]
function class:get(asDependency: boolean?)
	if asDependency ~= false then
		useDependency(self)
	end
	return self._value
end

--[[
	Updates the value stored in this State object.

	If `force` is enabled, this will skip equality checks and always update the
	state object and any dependents - use this with care as this can lead to
	unnecessary updates.
]]
function class:set(newValue: any, force: boolean?)
	-- if the value hasn't changed, no need to perform extra work here
	if self._value == newValue and not force then
		return
	end

	self._value = newValue

	-- update any derived state objects if necessary
	updateAll(self)
end

local function State(initialValue: any)
	local self = setmetatable({
		type = "State",
		kind = "State",
		-- if we held strong references to the dependents, then they wouldn't be
		-- able to get garbage collected when they fall out of scope
		dependentSet = setmetatable({}, WEAK_KEYS_METATABLE),
		_value = initialValue
	}, CLASS_METATABLE)

	initDependency(self)

	return self
end

return State