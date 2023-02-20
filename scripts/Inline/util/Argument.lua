local HttpService = game:GetService("HttpService")

local DEFAULTS = {
    ['boolean'] = false,
    ['number'] = 1,
    ['string'] = "",
}

local Argument = {}
Argument.__index = Argument
Argument.__metatable = {}

function Argument.new(name, description, type, required)
    local self = {}
    self.Name = name or "unknown argument"
    self.Description = description or nil
    self.Type = type or "string"
    self.Required = required or false
    self._default = DEFAULTS[type]

    setmetatable(self, Argument)
    return self
end

function Argument:assume(str: string)
    if self.Required then
        local success, realVariable = pcall(HttpService.JSONDecode, HttpService, str)
        if success then
            local realType = type(realVariable)
            if realType == self.Type then
                return realVariable
            else
                error(string.format(UIX.Inline.Messages.invalid_argument_type, self.Type, realType))
            end
        else
            error(string.format(UIX.Inline.Messages.unknown_variable, self.Name))
        end
    else
        local _, _variable = pcall(HttpService.JSONDecode, HttpService, str)
        local realVariable = _variable or self._default
        local realType = type(realVariable)
        if realType == self.Type then
            return realVariable
        else
            error(string.format(UIX.Inline.Messages.invalid_argument_type, self.Type, realType))
        end
    end
end

return Argument