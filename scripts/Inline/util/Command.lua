local GenericUtility = UIX.Require:get("GenericUtility")
local Argument = UIX.Inline.Require:import('/util/Argument.lua')

local Command = {}
Command.__index = Command

function Command.new(name)
    local self = setmetatable({
        Name = name,

        Arguments = {},
        Callback = nil,
    }, Command)

    return self
end

function Command:createArguments(...)
    for argument in pairs(GenericUtility:Set(...)) do
        table.insert(self.Arguments, Argument.new(argument[1], argument[3], argument[2]))
    end
end

function Command:execute(context: {string}) -- this is called on a pcall btw
    local realArgs = {}
    for i = 1, #self.Arguments do
        local argument = self.Arguments[i]
        table.insert(realArgs, argument:assume(context[i]))
    end
    if self.Callback then
        self.Callback(unpack(realArgs))
    else
        error(string.format(UIX.Inline.Messages.no_callback, self.Name))
    end
end

return Command