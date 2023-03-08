local GenericUtility = UIX.Require:get("GenericUtility")
local Argument = UIX.Inline.Require:import('/util/Argument.lua')

local Command = {}
Command.__index = Command

function Command.new(name)
    local self = setmetatable({
        Name = name,

        Userdata = {},
        Arguments = {},
        Callback = nil,
    }, Command)

    return function(fn)
        fn(self.Userdata)
        return self
    end
end

function Command:createArgument(argument)
    local arg = Argument.new(argument[1], argument[2], argument[3])
    table.insert(self.Arguments, arg)
    if argument[4] then
        arg:expects(argument[4])
    end
    return arg
end

function Command:createArguments(...)
    for argument in pairs(GenericUtility:Set(...)) do
        table.insert(self.Arguments, self:createArgument(argument))
    end
end

function Command:setCallback(callback)
    self.Callback = callback
end

function Command:execute(context: {string}) -- this is called on a pcall btw
    local realArgs = {}
    for i = 1, #self.Arguments do
        local argument = self.Arguments[i]
        table.insert(realArgs, argument:assume(context[i]))
    end
    if self.Callback then
        self.Callback(self, unpack(realArgs))
    else
        error(string.format(UIX.Inline.Messages.no_callback, self.Name))
    end
end

return Command