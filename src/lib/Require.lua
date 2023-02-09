local cached_imports = {}

local url = string.format(
    '',
    'weeeeee8',
    'main'
)

local Require = {}
function Require:import(urlToImport: string, invokeFunctionOnImport, ...)
    if url:sub(1, #urlToImport):lower() ~= urlToImport:lower() then
        warn('Importing unidentified module off the web.')
    elseif not url:find('https://', 1) then
        urlToImport = url .. urlToImport
    end

    local _t = string.split(urlToImport, '/')
    local scope = _t[#_t]
    local stored_import = self:get(scope)
    if stored_import then
        return stored_import
    end

    local success, chunk = pcall(game.HttpGet, game, urlToImport)
    if success then
        local src = loadstring(chunk, scope)
        if (typeof(src) == "function") and invokeFunctionOnImport then
            src = src(...)
        end
        cached_imports[scope:gsub(".lua", '')] = src
        return src
    end
end

function Require:get(name)
    return assert(cached_imports[name], "Library/Module '" .. name .. "' cannot be found.")
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