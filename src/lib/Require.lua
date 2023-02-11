local cached_imports = {}

local url = string.format(
    'https://raw.githubusercontent.com/%s/uiX/%s/src',
    'weeeeee8',
    'main'
)

local Require = {}
function Require:import(urlToImport: string, invokeFunctionOnImport, ...)
    if not urlToImport:find('https://', 1) then
        if urlToImport:sub(-1, 1) ~= '/' then
            urlToImport = '/' .. urlToImport
        end
        urlToImport = url .. urlToImport
    elseif url:find('https://', 1) and url:sub(1, #urlToImport):lower() ~= urlToImport:lower() then
        warn('Importing unidentified module off the web.')
    end


    if urlToImport:find("Require.lua") then
        error("Cannot import script.")
    end

    local _t = string.split(urlToImport, '/')
    local scope = _t[#_t]
    local name = scope:gsub(".lua", '')
    local stored_import = cached_imports[name]
    if stored_import then
        return stored_import
    end

    local success, chunk = pcall(game.HttpGet, game, urlToImport)
    if success then
        local src = loadstring(chunk, scope)
        if (typeof(src) == "function") and invokeFunctionOnImport then
            src = src(...)
        end
        cached_imports[name] = src
        return src
    end
end

function Require:get(name)
    return assert(cached_imports[name], "Library/Module '" .. name .. "' cannot be found.")
end

function Require:clearCache()
    table.clear(cached_imports)
end

setmetatable(Require, {
    __index = function(_,k)
        error("'" .. k .. "' does not exist.")
    end,
    __newindex = function(_, k)
        error("Cannot assign property '" .. k .. "'.")
    end,
})

return Require