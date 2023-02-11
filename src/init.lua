local FILE_PATHS = {
    folder = 'uix',
    plugins_folder = 'uix/plugins',
    saves_folder = 'uix/saves'
}

local env = assert(getgenv, 'Cannot find "getgenv" global, could it be exploit is not supported?')()

local function reconcilefolder(path)
    if not isfolder(path) then
        makefolder(path)
    end
end

local function reconcilefile(path)
    if not isfile(path) then
        writefile(path)
    end
end

reconcilefolder(FILE_PATHS.folder)
reconcilefolder(FILE_PATHS.plugins_folder)
reconcilefolder(FILE_PATHS.saves_folder)

env.__GLOBAL__ = env
env.UIX = {
    Require = loadstring(game:HttpGet(string.format(
        'https://raw.githubusercontent.com/%s/uiX/%s/src/lib/Require.lua',
        'weeeeee8',
        'main'
    ))),
    reconcilefile = reconcilefile,
    reconcilefolder = reconcilefolder
}