local Command = UIX.Inline.Require:import('/util/Command.lua')

local PackageAPI = {}
PackageAPI.__index = PackageAPI
function PackageAPI:createCommand(name)
    local command = Command.new(name)
    table.insert(self.Commands, command)
    return command
end

return function(packageName: string)
    local self = setmetatable({
        Name = packageName,
        Commands = {},
    }, PackageAPI)

    table.insert(UIX.Inline.Packages, self)
    return self
end