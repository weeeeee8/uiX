__GLOBAL__.__FUSION_SRC_PATH__ = function(path)
    return '/packages/fusion' .. path
end

local Types = UIX.Require:import(__FUSION_SRC_PATH__('/Types.lua'))
local restrictRead = UIX.Require:import(__FUSION_SRC_PATH__('/Utility/restrictRead.lua'))

export type State = Types.State
export type StateOrValue = Types.StateOrValue
export type Symbol = Types.Symbol

return restrictRead("Fusion", {
	New = UIX.Require:import(__FUSION_SRC_PATH__('/Instances/New.lua')),
	Children = UIX.Require:import(__FUSION_SRC_PATH__('/Instances/Children.lua')),
	OnEvent = UIX.Require:import(__FUSION_SRC_PATH__('/Instances/OnEvent.lua')),
	OnChange = UIX.Require:import(__FUSION_SRC_PATH__('/Instances/OnChange.lua')),

	State = UIX.Require:import(__FUSION_SRC_PATH__('/State/State.lua')),
	Computed = UIX.Require:import(__FUSION_SRC_PATH__('/State/Computed.lua')),
	ComputedPairs = UIX.Require:import(__FUSION_SRC_PATH__('/State/ComputedPairs.lua')),
	Compat = UIX.Require:import(__FUSION_SRC_PATH__('/State/Compat.lua')),

	Tween = UIX.Require:import(__FUSION_SRC_PATH__('/Animation/Tween.lua')),
	Spring = UIX.Require:import(__FUSION_SRC_PATH__('/Animation/Spring.lua')),
})