local UIX = loadstring(game:HttpGet(string.format(
    'https://raw.githubusercontent.com/%s/uiX/%s/src/init.lua',
    'weeeeee8',
    'main'
)))()

local extendedRequire = UIX.Require:wrap(string.format(
    'https://raw.githubusercontent.com/%s/uiX/%s/scripts/Inline',
    'weeeeee8',
    'main'
))

UIX.Require:import('/modules/fusion/Fusion.lua', true)
UIX.Require:import('/lib/GenericUtility.lua', true)
UIX.Require:import('/modules/Signal.lua', true)
local Maid = UIX.Require:get('Maid')

UIX.Inline = {
    Require = extendedRequire,
    Maid = Maid.new(),

    Packages = {},
    Messages = {
        unknown_variable = "Unknown variable from argument '%s'",
        invalid_argument_type = "Invalid argument type; expect '%s', got '%s'",
        cannot_find_command = "Cannot find command '%s'",
        successfully_invoked_command = "Successfully invoked command '%s'",
    }
}

UIX.Maid:GiveTask(function()
    UIX.Inline.Require:clearCache()
    UIX.Inline.Maid:Destroy()
    table.clear(UIX.Inline)
end)

extendedRequire:import("/util/createPackage.lua")
extendedRequire:import("/ui/legacy.lua")