--[[
	Constructs and returns objects which can be used to model derived reactive
	state.
]]

local captureDependencies = UIX.Require:import(__FUSION_SRC_PATH__('/Dependencies/captureDependencies.lua'))
local initDependency = UIX.Require:import(__FUSION_SRC_PATH__('/Dependencies/initDependency.lua'))
local useDependency = UIX.Require:import(__FUSION_SRC_PATH__('/Dependencies/useDependency.lua'))
local logErrorNonFatal = UIX.Require:import(__FUSION_SRC_PATH__('/Logging/logErrorNonFatal.lua'))

local class = {}

local CLASS_METATABLE = {__index = class}
local WEAK_KEYS_METATABLE = {__mode = "k"}

--[[
	Returns the last cached value calculated by this Computed object.
	The computed object will be registered as a dependency unless `asDependency`
	is false.
]]
function class:get(asDependency: boolean?)
	if asDependency ~= false then
		useDependency(self)
	end
	return self._value
end

--[[
	Recalculates this Computed's cached value and dependencies.
	Returns true if it changed, or false if it's identical.
]]
function class:update()
	-- remove this object from its dependencies' dependent sets
	for dependency in pairs(self.dependencySet) do
		dependency.dependentSet[self] = nil
	end

	-- we need to create a new, empty dependency set to capture dependencies
	-- into, but in case there's an error, we want to restore our old set of
	-- dependencies. by using this table-swapping solution, we can avoid the
	-- overhead of allocating new tables each update.
	self._oldDependencySet, self.dependencySet = self.dependencySet, self._oldDependencySet
	table.clear(self.dependencySet)

	local ok, newValue = captureDependencies(self.dependencySet, self._callback)

	if ok then
		local oldValue = self._value
		self._value = newValue

		-- add this object to the dependencies' dependent sets
		for dependency in pairs(self.dependencySet) do
			dependency.dependentSet[self] = true
		end

		return oldValue ~= newValue
	else
		-- this needs to be non-fatal, because otherwise it'd disrupt the
		-- update process
		logErrorNonFatal("computedCallbackError", newValue)

		-- restore old dependencies, because the new dependencies may be corrupt
		self._oldDependencySet, self.dependencySet = self.dependencySet, self._oldDependencySet

		-- restore this object in the dependencies' dependent sets
		for dependency in pairs(self.dependencySet) do
			dependency.dependentSet[self] = true
		end

		return false
	end
end

local function Computed(callback: () -> any)
	local self = setmetatable({
		type = "State",
		kind = "Computed",
		dependencySet = {},
		-- if we held strong references to the dependents, then they wouldn't be
		-- able to get garbage collected when they fall out of scope
		dependentSet = setmetatable({}, WEAK_KEYS_METATABLE),
		_oldDependencySet = {},
		_callback = callback,
		_value = nil,
	}, CLASS_METATABLE)

	initDependency(self)
	self:update()

	return self
end

return Computed