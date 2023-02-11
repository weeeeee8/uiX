--[[
	Restricts the reading of missing members for a table.
]]

local logError = UIX.Require:import(__FUSION_SRC_PATH__('/Logging/logError.lua'))

local function restrictRead(tableName: string, strictTable: table): table
	local metatable = getmetatable(strictTable)

	if metatable == nil then
		metatable = {}
		setmetatable(strictTable, metatable)
	end

	function metatable:__index(memberName)
		logError("strictReadError", nil, tostring(memberName), tableName)
	end

	return strictTable
end

return restrictRead