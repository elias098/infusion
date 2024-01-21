local io = require("io")
local serialization = require("serialization")

local exec = {}

local config
do
    local configFile = io.open("config")
    if configFile ~= nil then
        config = serialization.unserialize(configFile:read("*a"))
        configFile:close()
    else
        config = {}
    end
end


local function saveConfig()
    local configFile = io.open("config", "w")
    if configFile == nil then
        error("Unable to write to config")
    end
    configFile:write(serialization.serialize(config))
    configFile:close()
end

function exec.getOrDefault(field, default)
    if config[field] == nil then
        config[field] = default
        saveConfig()
    end

    return config[field]
end

function exec.getOrDefaultFn(field, default)
    if config[field] == nil then
        config[field] = default()
        saveConfig()
    end

    return config[field]
end

function exec.setConfig(field, value)
    config[field] = value
    saveConfig()
end

function exec.modifyConfig(field, callback)
    config[field] = callback(config[field])
    saveConfig()
end

return exec
