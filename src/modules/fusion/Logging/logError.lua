--[[
	Utility function to log a Fusion-specific error.
]]

local Types = UIX.Require:import(__FUSION_SRC_PATH__('/Types.lua'))
local messages = UIX.Require:import(__FUSION_SRC_PATH__('/Logging/messages.lua'))

local function logError(messageID: string, errObj: Types.Error?, ...)
	local formatString = messages[messageID]

	if formatString == nil then
		messageID = "unknownMessage"
		formatString = messages[messageID]
	end

	local errorString
	if errObj == nil then
		errorString = string.format("[Fusion] " .. formatString .. "\n(ID: " .. messageID .. ")", ...)
	else
		formatString = formatString:gsub("ERROR_MESSAGE", errObj.message)
		errorString = string.format("[Fusion] " .. formatString .. "\n(ID: " .. messageID .. ")\n---- Stack trace ----\n" .. errObj.trace, ...)
	end

	error(errorString:gsub("\n", "\n    "), 0)
end

return logError