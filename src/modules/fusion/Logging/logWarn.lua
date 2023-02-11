--[[
	Utility function to log a Fusion-specific warning.
]]

local messages = UIX.Require:import(__FUSION_SRC_PATH__('/Logging/messages.lua'))

local function logWarn(template, ...)
	local formatString = messages[template]

	if formatString == nil then
		template = "unknownMessage"
		formatString = messages[template]
	end

	warn(string.format("[Fusion] " .. formatString .. "\n(ID: " .. template .. ")", ...))
end

return logWarn