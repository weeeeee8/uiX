--[[
	If a target set was specified by captureDependencies(), this will add the
	given dependency to the target set.
]]


local Types = UIX.Require:import(__FUSION_SRC_PATH__('/Types.lua'))
local sharedState = UIX.Require:import(__FUSION_SRC_PATH__('/Dependencies/sharedState.lua'))

local initialisedStack = sharedState.initialisedStack

local function useDependency(dependency: Types.Dependency<any>)
	local dependencySet = sharedState.dependencySet

	if dependencySet ~= nil then
		local initialisedStackSize = sharedState.initialisedStackSize
		if initialisedStackSize > 0 then
			local initialisedSet = initialisedStack[initialisedStackSize]
			if initialisedSet[dependency] ~= nil then
				return
			end
		end
		dependencySet[dependency] = true
	end
end

return useDependency