--[[
	An xpcall() error handler to collect and parse useful information about
	errors, such as clean messages and stack traces.
]]

local Types = UIX.Require:import(__FUSION_SRC_PATH__('/Types.lua'))

local function parseError(err: string): Types.Error
	return {
		raw = err,
		message = err:gsub("^.+:%d+:%s*", ""),
		trace = debug.traceback(nil, 2)
	}
end

return parseError