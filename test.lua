local component = require("component")
local gui = require("infusion.gui")
local io = require("io")
local serialization = require("serialization")
local config = require("infusion.config")
local io = require("os")
local event = require("event")
local gpu = component.gpu
local essentia = require("infusion.essentia")
local recipes = require("infusion.recipes")

local interface = component.proxy(config.getOrDefault("interface", component.me_interface.address))
local screenWidth, screenHeight = gpu.getResolution()

gui.clear()
gui.drawBorder({ x = 1, y = 1 }, { x = screenWidth, y = screenHeight }, 0x555555, "Infusion automation", 0xADD8E6)

local altarWidth = 52
local altarheight = 23

local function checkComponents(altar)
    if altar.transposer ~= nil then
        for i = 0, 5, 1 do
            local name = altar.transposer.getInventoryName(i)

            if name == "tile.blockStoneDevice" then
                altar.pedestalSide = i
            elseif name == "tile.appliedenergistics2.BlockInterface" then
                altar.interfaceSide = i
            end
        end
    end

    return altar.matrix ~= nil
        and altar.interface ~= nil
        and altar.redstone ~= nil
        and altar.transposer ~= nil
end

local linking = nil

local function checkState(altar)
    if linking == altar.id then
        return "linking"
    elseif not altar.hasComponents then
        return "missing components"
    else
        local state = altar.newState
        altar.newState = nil
        return state or altar.state or "ready"
    end
end

local altarAddresses = config.getOrDefault("altars", { {}, {}, {}, {}, {}, {} })
local altars = {}
for i = 1, 6, 1 do
    local altar = {
        pos = {
            x = (i - 1) % 3 * altarWidth + 3,
            y = math.floor((i - 1) / 3) * altarheight + 3
        }
    }

    for componentType, address in pairs(altarAddresses[i]) do
        altar[componentType] = component.proxy(address)
    end

    altar.hasComponents = checkComponents(altar)
    altar.clean = function() end
    altar.id = i

    altars[#altars + 1] = altar
end

local function getAddress(altar, component)
    if altar[component] ~= nil then
        return altar[component].address
    end

    return "none"
end

local function updateAltar(altar)
    if altar.update == "once" then
        altar.update = false
    end

    if altar.state == "ready" then
        local input = altar.transposer.getStackInSlot(altar.pedestalSide, 1)
        if input == nil then
            return
        end

        local items = {}
        for item in altar.interface.allItems() do
            items[#items + 1] = {
                label = item.label,
                size = item.size
            }
        end

        local recipe = recipes.getRecipe(input.label, items)

        if recipe ~= nil then
            altar.recipe = recipe
            altar.newState = "waiting for essentia"
        end
    elseif altar.state == "waiting for essentia" then
        local currentEssentia = essentia.get(interface)

        for _, aspect in ipairs(altar.recipe.essentia) do
            if (currentEssentia[aspect.aspect] or 0) < aspect.amount then
                return
            end
        end

        for _, aspect in ipairs(altar.recipe.essentia) do
            currentEssentia[aspect.aspect] = (currentEssentia[aspect.aspect] or 0) - aspect.amount
        end

        altar.redstone.setOutput({ [0] = 15, [1] = 15, [2] = 15, [3] = 15, [4] = 15, [5] = 15 })
        altar.redstone.setOutput({ [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0 })
        if type(altar.matrix.getAspects().aspects) == "table" then
            altar.newState = "essentia"
        end
    elseif altar.state == "essentia" then
        local currentEssentia = essentia.get(interface)
        local matrixEssentia = altar.matrix.getAspects().aspects

        local finished = true
        for _, aspect in pairs(matrixEssentia) do
            if aspect.amount > 0 then
                currentEssentia[aspect.name] = (currentEssentia[aspect.name] or 0) - aspect.amount
                finished = false
            end
        end

        if finished then
            altar.newState = "crafting"
        end
    elseif altar.state == "crafting" then
        local item = altar.transposer.getStackInSlot(altar.pedestalSide, 1)

        if item.label == altar.recipe.output.label and item.damage == altar.recipe.output.damage then
            for _ = 1, item.size, 1 do
                while true do
                    if altar.transposer.transferItem(altar.pedestalSide, altar.interfaceSide, 1, 1, 1) > 0 then
                        break
                    else
                        if altar.transposer.getStackInSlot(altar.pedestalSide, 1).label ~= altar.recipe.output then
                            goto outer
                        end
                    end
                end
            end

            ::outer::
            altar.newState = "ready"
        elseif item.label ~= altar.recipe.input.label then
            altar.newState = "ready"
        end
    elseif altar.state == "linking" then
        local x = altar.pos.x + 2
        local y = altar.pos.y + 1
        local max_x = x + screenWidth - 4

        gui.writeTextClamped("matrix:     " .. getAddress(altar, "matrix"), y, 0xADD8E6, nil, x, max_x)
        gui.writeTextClamped("interface:  " .. getAddress(altar, "interface"), y + 1, 0xADD8E6, nil, x, max_x)
        gui.writeTextClamped("redstone:   " .. getAddress(altar, "redstone"), y + 2, 0xADD8E6, nil, x, max_x)
        gui.writeTextClamped("transposer: " .. getAddress(altar, "transposer"), y + 3, 0xADD8E6, nil, x, max_x)
    end
end


local function setupAltar(altar)
    if altar.state == "ready" then
        altar.update = true

        gui.drawBorder(altar.pos, { x = altarWidth, y = altarheight }, 0x555555, "Altar " .. altar.matrix.address,
            0xADD8E6)

        local x1 = altar.pos.x + 1
        local y1 = altar.pos.y + 1

        local x2 = x1 + altarWidth - 3
        local y2 = y1 + altarheight - 3

        altar.clean = gui.createButtonWithCleanup(x1, y1, x2, y2, function() linking = altar.id end, "", 0, 0xADD8E6)
    elseif altar.state == "waiting for essentia" then
        altar.update = true
    elseif altar.state == "essentia" then
        altar.update = true
    elseif altar.state == "crafting" then
        altar.update = true
    elseif altar.state == "missing components" then
        gui.drawBorder(altar.pos, { x = altarWidth, y = altarheight }, 0x555555, "No altar", 0xADD8E6)

        local x1 = altar.pos.x + 1
        local y1 = altar.pos.y + 1

        local x2 = x1 + altarWidth - 3
        local y2 = y1 + altarheight - 3

        altar.clean = gui.createButtonWithCleanup(x1, y1, x2, y2, function() linking = altar.id end, "test", 0, 0xADD8E6)
    elseif altar.state == "linking" then
        altar.update = "once"

        gui.drawBorder(altar.pos, { x = altarWidth, y = altarheight }, 0x555555, "Linking altar", 0xADD8E6)

        local x1 = altar.pos.x + 1
        local y1 = altar.pos.y + 1

        local x2 = x1 + altarWidth - 3
        local y2 = y1 + altarheight - 3

        local cleanButton = gui.createButtonWithCleanup(x1, y1, x2, y2, function() linking = nil end, "", 0, 0xADD8E6)

        local listener = function(_, address, componentType)
            if componentType == "me_interface" then
                altarAddresses[altar.id].interface = address
                altar.interface = component.proxy(address)
            elseif componentType == "blockstonedevice_2" then
                altarAddresses[altar.id].matrix = address
                altar.matrix = component.proxy(address)
            elseif componentType == "redstone" then
                altarAddresses[altar.id].redstone = address
                altar.redstone = component.proxy(address)
            elseif componentType == "transposer" then
                altarAddresses[altar.id].transposer = address
                altar.transposer = component.proxy(address)
            else
                return
            end

            config.setConfig("altar", altarAddresses)
            altar.update = "once"
            altar.hasComponents = checkComponents(altar)
        end

        event.listen("component_added", listener)

        altar.clean = function()
            event.ignore("component_added", listener)
            cleanButton()
        end
    end
end

local function drawAltar(altar)
    local oldState = altar.state
    local state = checkState(altar)

    if oldState ~= state then
        altar.state = state
        altar.clean()
        altar.update = false
        setupAltar(altar)
    end

    if altar.update then
        updateAltar(altar)
    end
end

while true do
    for _, altar in ipairs(altars) do
        drawAltar(altar)
    end

    essentia.invalidate()
    ---@diagnostic disable-next-line: undefined-field
    os.sleep(0.05)
end
