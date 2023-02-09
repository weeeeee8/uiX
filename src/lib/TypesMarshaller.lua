return function(dataObj)
    local type = type(dataObj)

    if type == "table" then
        local meta = getmetatable(dataObj)
        local name = tostring(meta)
        if name then
            return name
        end
    end

    return type
end