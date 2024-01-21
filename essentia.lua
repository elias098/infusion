local exec = {}

local essentia = nil

function exec.get(interface)
    if essentia == nil then
        essentia = {}
    end

    local currentEssentia = interface.getEssentiaInNetwork()

    for _, aspect in ipairs(currentEssentia) do
        local strStart, strEnd = string.find(aspect.label, " Super Critical Fluid")
        local label = string.sub(aspect.label, 0, strStart - 1)

        essentia[label] = aspect.amount
    end

    return essentia
end

function exec.invalidate()
    essentia = nil
end

return exec
