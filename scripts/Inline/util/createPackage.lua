local Command = UIX.Inline.Require:import('/util/Command.lua')

local PackageAPI = {}
PackageAPI.__index = PackageAPI
function PackageAPI:createCommand(name)
    local command = Command.new(name)
    table.insert(self.Commands, command)
    return command
end

function PackageAPI:getCommandsFromInput(input: string, listDirection: Enum.SortDirection?)
    local commands = {}
    for i = 1, #self.Commands do
        local name = self.Commands[i].Name
        if name:sub(1, #input) == input then
            table.insert(commands, {
                len = #name,
                command = self.Commands[i]
            })
        end
    end
    table.sort(commands, function(a, b)
        return if listDirection == Enum.SortDirection.Ascending then a.len > b.len else a.len < b.len
    end)
    return if commands[1] then commands[1].command else nil
end

return function(packageName: string)
    local self = setmetatable({
        Name = packageName,
        Commands = {},
    }, PackageAPI)

    UIX.Inline.Packages[self] = true

    return self
end