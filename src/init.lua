local FILE_PATHS = {
    folder = 'uix',
    plugins_folder = 'uix/plugins',
    saves_folder = 'uix/saves',
}

local env = assert(getgenv, 'Cannot find "getgenv" global, could it be exploit is not supported?')()

local function reconcilefolder(path)
    if not isfolder(path) then
        makefolder(path)
    end
end

local function reconcilefile(path)
    if not isfile(path) then
        writefile(path, "")

        return true
    end

    return false
end

reconcilefolder(FILE_PATHS.folder)
reconcilefolder(FILE_PATHS.plugins_folder)
reconcilefolder(FILE_PATHS.saves_folder)

if env.UIX then
    env.UIX:Clean()
end

env.__GLOBAL__ = env
env.UIX = {
    Clean = function(self)
        env.UIX.Require:clearCache()
        env.UIX.Maid:Destroy()
    end,
    
    FilePaths = FILE_PATHS,
    Require = loadstring(game:HttpGet(string.format(
        'https://raw.githubusercontent.com/%s/uiX/%s/src/lib/Require.lua',
        'weeeeee8',
        'main'
    )))(),
    reconcilefile = reconcilefile,
    reconcilefolder = reconcilefolder
}

local Maid = env.UIX.Require:import("/modules/Maid.lua")
env.UIX.Maid = Maid.new()

return env.UIX