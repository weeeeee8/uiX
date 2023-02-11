--[[
	Registers the creation of an object which can be used as a dependency.

	This is used to make sure objects don't capture dependencies originating
	from inside of themselves.
]]

local Types = UIX.Require:import(__FUSION_SRC_PATH__('/Types.lua'))
local sharedState = UIX.Require:import(__FUSION_SRC_PATH__('/Dependencies/sharedState.lua'))

local initialisedStack = sharedState.initialisedStack

local function initDependency(dependency: Types.Dependency<any>)
	local initialisedStackSize = sharedState.initialisedStackSize

	for index, initialisedSet in ipairs(initialisedStack) do
		if index > initialisedStackSize then
			return
		end

		initialisedSet[dependency] = true
	end
end

return initDependency