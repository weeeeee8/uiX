local TypesMarshaller = UIX.Require:import("/lib/TypesMarshaller.lua")
local Signal = UIX.Require:import("/modules/Signal.lua")

local VECTOR_XZ = Vector3.new(1, 0, 1)

local GenericUtilityInternal = {}

GenericUtilityInternal.State = {} do
    GenericUtilityInternal.State.__index = GenericUtilityInternal.State
    function GenericUtilityInternal.State.new(initialValue)
        local self = setmetatable({
            IsState = true,
            _v = initialValue,
            _changed = Signal.new()
        }, GenericUtilityInternal.State)
        self._changed:Fire(self._v, nil)
        return self
    end

    function GenericUtilityInternal.State:set(newValue, forceValue)
        if (self._v ~= newValue) or forceValue then
            self._changed:Fire(newValue, self._v)
            self._v = newValue
        end
    end

    function GenericUtilityInternal.State:get()
        return self._v
    end

    function GenericUtilityInternal.State:onChanged(fn)
        return self._changed:Connect(fn)
    end
end

GenericUtilityInternal.Stack = {
    __tostring = function() return "StackObject" end,
    __metatable = {},
} do
    GenericUtilityInternal.Stack.__index = GenericUtilityInternal.Stack

    function GenericUtilityInternal.Stack.new()
        return setmetatable({}, GenericUtilityInternal.Stack)
    end

    function GenericUtilityInternal.Stack:push(input)
        self[#self+1] = input
    end

    function GenericUtilityInternal.Stack:pop()
        if #self < 0 then
            warn("Stack underflow!")
            return nil
        end

        local output = self[#self]
        self[#self] = nil
        return output
    end

    function GenericUtilityInternal.Stack:foreach(fn)
        for i, v in ipairs(self) do
            local thread = coroutine.create(fn)
            coroutine.resume(thread, i, v)
        end
    end
end

GenericUtilityInternal.TableUtil = {}
function GenericUtilityInternal.TableUtil.QuickSort(target, discriminant, direction)
    assert(direction == "ascending" or direction == "descending", "Unable to cast token 'direction'")
    assert(target, "Argument 1 cannot be nil")
    assert(discriminant, 'Argument 2 cannot be nil')
    assert(type(discriminant) == "string", 'Argument 2 must be a string')
    table.sort(target, function(a, b)
        if direction == "ascending" then
            return a[discriminant] < b[discriminant]
        elseif direction == "descending" then
            return a[discriminant] > b[discriminant]
        else
            error("Invalid sorting direction.")
        end
    end)
end

GenericUtilityInternal.Neighbors = {
    __tostring = function() return "NeighborsContainer" end,
    __metatable = {},
} do
    GenericUtilityInternal.Neighbors.__index = GenericUtilityInternal.Neighbors

    function GenericUtilityInternal.Neighbors.new()
        return setmetatable({
            _neighbors = GenericUtilityInternal.Stack.new()
        }, GenericUtilityInternal.Neighbors)
    end

    function GenericUtilityInternal.Neighbors:node(position)
        self._neighbors:push(position)
    end

    function GenericUtilityInternal.Neighbors:search(position, radius, searchType)
        assert(position, 'Argument 1 cannot be nil')
        radius = radius or 100
        searchType = (searchType or "manhattan"):lower():gsub(" ", "")

        local nearest = {}
        self._neighbors:foreach(function(i, v)
            local dist
            if searchType == "manhattan" then
                dist = ((v - position) * VECTOR_XZ).Magnitude
            elseif searchType == "euclidean" then
                dist = (v - position).Magnitude
            else
                error("Unsupported search type.")
            end

            table.insert(nearest, {dist, v})
        end)
        GenericUtilityInternal.TableUtil.QuickSort(nearest, "dist", "ascending")
        return if nearest[1] then nearest[1][2] else nil
    end

    function GenericUtilityInternal.Neighbors:pathfind(start, goal, obstructsWithWorld)
        error("Not yet supported.")

        start = self:search(start, nil, "euclidean")
        goal = self:search(goal, nil, "euclidean")
    end
end

function GenericUtilityInternal:Set(...)
    local set = {}
    for _, key in {...} do
        set[key] = true
    end
    return set
end

function GenericUtilityInternal:Symbol(name)
	local symbol = newproxy(true)
	if not name then
		name = ""
	end
	getmetatable(symbol).__tostring = function()
		return "Symbol(" .. name .. ")"
	end
	return symbol
end

local GenericUtility = {}
function GenericUtility:assign(utilName, utilFn)
    GenericUtilityInternal[assert(utilName, 'Argument 1 cannot nil')] = utilFn
end

setmetatable(GenericUtility, {
    __index = function(_,k)
        if GenericUtilityInternal[k] then
            return GenericUtilityInternal[k]
        else
            error("'" .. k .. "' does not exist.")
        end
    end,
    __newindex = function(_, k)
        error("Cannot assign property '" .. k .. "'.")
    end,
})

return GenericUtility