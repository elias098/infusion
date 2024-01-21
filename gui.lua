local component = require("component")
local event = require("event")
local unicode = require("unicode")

local gpu = component.gpu

local gui = {}

---@param text string
---@param line number
---@param color number
---@param background_color nil | number | string
---@param min_x number
---@param max_x number
function gui.writeTextCentered(text, line, color, background_color, min_x, max_x)
    local width, height = gpu.getResolution()
    local fg_default = gpu.getForeground()
    local bg_default = gpu.getBackground()

    if not min_x then
        min_x = 1
    end
    if not max_x then
        max_x = width
    end
    if color then
        gpu.setForeground(color)
    end
    if background_color and background_color ~= "preserve" then
        gpu.setBackground(background_color)
    end

    local maxlength = max_x - min_x + 1

    text = unicode.sub(text, 1, maxlength)

    local leftover_space = maxlength - unicode.wlen(text)

    local starting_x = min_x + math.floor(leftover_space / 2)

    local posY = math.min(height, line)

    if background_color == "preserve" then
        local char_counter = 1
        for posX = starting_x, starting_x + unicode.len(text) do
            local _, _, background = gpu.get(posX, posY)
            gpu.setBackground(background)
            gpu.set(posX, posY, string.sub(text, char_counter, char_counter))
            char_counter = char_counter + 1
        end
    else
        gpu.set(starting_x, posY, text)
    end
    gpu.setForeground(fg_default)
    gpu.setBackground(bg_default)
end

---@param text string
---@param line number
---@param color number
---@param background_color nil | number | string
---@param x number
---@param max_length number
function gui.writeTextClamped(text, line, color, background_color, x, max_length)
    local width, height = gpu.getResolution()
    local fg_default = gpu.getForeground()
    local bg_default = gpu.getBackground()

    if not min_x then
        min_x = 1
    end
    if not max_x then
        max_x = width
    end
    if color then
        gpu.setForeground(color)
    end
    if background_color and background_color ~= "preserve" then
        gpu.setBackground(background_color)
    end

    text = unicode.sub(text, 1, max_length)

    if background_color == "preserve" then
        --local char_counter = 1
        --for posX = starting_x, starting_x + unicode.len(text) do
        --    local _, _, background = gpu.get(posX, posY)
        --    gpu.setBackground(background)
        --    gpu.set(posX, posY, string.sub(text, char_counter, char_counter))
        --    char_counter = char_counter + 1
        --end
    else
        gpu.set(x, line, text)
    end
    gpu.setForeground(fg_default)
    gpu.setBackground(bg_default)
end

function gui.createButtonWithCleanup(x1, y1, x2, y2, callback, text, background_color, text_color)
    if text_color == nil then
        text_color = 0xFFFFFF
    end

    local bg_default
    if background_color ~= nil then
        bg_default = gpu.setBackground(background_color)
    end

    local width = x2 - x1 + 1
    local height = y2 - y1 + 1

    gpu.fill(x1, y1, width, height, " ")

    if text ~= nil and text ~= "" then
        gui.writeTextCentered(text, y1 + math.floor(height / 2), text_color, background_color, x1, x2)
    end

    if bg_default ~= nil then
        gpu.setBackground(bg_default)
    end

    local buttonOnTouch = function(_, _, x, y, button, player)
        if x >= x1 and x <= x2 and y >= y1 and y <= y2 then
            callback(player, button)
        end
    end

    event.listen("touch", buttonOnTouch)

    return function()
        event.ignore("touch", buttonOnTouch)
        gpu.fill(x1, y1, width, height, " ")
    end
end

--region Buttons
local buttons = {}
---@param id string
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param callback function Is given the arguments `id, player, button` which contains the button id, player, and mouse button respectively.
---@param text string Optional
---@param background_color number Optional
---@param text_color number Optional, default: `0xFFFFFF`
function gui.createButton(id, x1, y1, x2, y2, callback, text, background_color, text_color)
    if id == nil then
        error("createButton missing required argument 'id'")
    end

    if text_color == nil then
        text_color = 0xFFFFFF
    end

    local bg_default
    if background_color ~= nil then
        bg_default = gpu.setBackground(background_color)
    end

    local width = x2 - x1 + 1
    local height = y2 - y1 + 1

    gpu.fill(x1, y1, width, height, " ")

    if text ~= nil and text ~= "" then
        gui.writeTextCentered(text, y1 + math.floor(height / 2), text_color, background_color, x1, x2)
    end

    if bg_default ~= nil then
        gpu.setBackground(bg_default)
    end

    local buttonOnTouch = function(_, _, x, y, button, player)
        if x >= x1 and x <= x2 and y >= y1 and y <= y2 then
            callback(player, button)
        end
    end

    event.listen("touch", buttonOnTouch)

    if buttons[id] == nil then
        buttons[id] = {}
    end

    buttons[id][#buttons[id] + 1] = {
        x1 = x1,
        y1 = y1,
        x2 = x2,
        y2 = y2,
        clear_event_listener = function()
            event.ignore("touch", buttonOnTouch)
        end
    }
end

function gui.clearButtons(id)
    if buttons[id] == nil then
        return
    end

    for i, button in ipairs(buttons[id]) do
        button.clear_event_listener()

        local width = button.x2 - button.x1 + 1
        local height = button.y2 - button.y1 + 1

        gpu.fill(button.x1, button.y1, width, height, " ")
    end

    buttons[id] = nil
end

function gui.clearAllButtons()
    for _, buttonList in pairs(buttons) do
        for i, button in ipairs(buttonList) do
            button.clear_event_listener()

            local width = button.x2 - button.x1 + 1
            local height = button.y2 - button.y1 + 1

            gpu.fill(button.x1, button.y1, width, height, " ")
        end
    end
end

---@param pos Coordinate2D
---@param size Coordinate2D
---@param border_color number
---@param title string?
---@param text_color number? Optional, default: `0xFFFFFF`
function gui.drawBorder(pos, size, border_color, title, text_color)
    gpu.setForeground(border_color)
    local top = '╭'
    local edges = '│'
    local bottom = '╰'
    for _ = 1, size.x - 2 do
        top = top .. '─'
        bottom = bottom .. '─'
    end
    for _ = 1, size.y - 3 do
        edges = edges .. '│'
    end
    top = top .. '╮'
    bottom = bottom .. '╯'

    gpu.set(pos.x, pos.y + 1, edges, true)
    gpu.set(pos.x + size.x - 1, pos.y + 1, edges, true)
    gpu.set(pos.x, pos.y, top)
    gpu.set(pos.x, pos.y + size.y - 1, bottom)

    gpu.setForeground(text_color)
    if title then
        gpu.set(pos.x + 2, pos.y, ' ' .. title .. ' ')
    end
end

---@param pos Coordinate2D?
---@param size Coordinate2D?
function gui.clear(pos, size)
    local screenWidth, screenHeight = gpu.getResolution()

    if pos == nil and size == nil then
        pos = { x = 1, y = 1 }
        size = { x = screenWidth, y = screenHeight }
    elseif pos ~= nil then
        pos = { x = 1, y = 1 }
    elseif size ~= nil then
        size = { x = 1, y = 1 }
    end

    gpu.fill(0, 0, screenWidth, screenHeight, " ")
end

return gui
