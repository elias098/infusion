local io = require("io")
local serialization = require("serialization")

local lookupFile = io.open("infusion/lookup.txt")
if lookupFile == nil then
    error("Unable to open lookup.txt")
end
local lookup = serialization.unserialize(lookupFile:read("*a"))
lookupFile:close()

local recipeFile = io.open("infusion/recipes.txt")
if recipeFile == nil then
    error("Unable to open recipes.txt")
end
local recipes = {}

---@param item { [1]: string, [2]: string, [3]: number, [4]: number }
---@return Item
local function parseItem(item)
    return {
        label = lookup[item[1]],
        name = lookup[item[2]],
        size = item[3],
        damage = item[4],
    }
end

---@param rawRecipeData string
---@return Recipe
local function parseRecipe(rawRecipeData)
    ---@type RawRecipe
    local rawRecipe = serialization.unserialize(rawRecipeData)
    local recipe = {}

    recipe.input = parseItem(rawRecipe[1])
    recipe.components = {}
    for _, item in ipairs(rawRecipe[2]) do
        recipe.components[#recipe.components + 1] = parseItem(item)
    end
    recipe.output = parseItem(rawRecipe[3])

    recipe.essentia = {}
    for _, aspect in ipairs(rawRecipe[4]) do
        recipe.essentia[#recipe.essentia + 1] = {
            aspect = lookup[aspect[1]],
            amount = aspect[2]
        }
    end

    return recipe
end

---@param index number
---@return Recipe
local function getRecipe(index)
    recipeFile:seek("set", index)
    local rawRecipeData = recipeFile:read("*l")

    return parseRecipe(rawRecipeData)
end

print("indexing recipes")

while true do
    local pos = recipeFile:seek()
    local rawRecipeData = recipeFile:read("*l")
    if rawRecipeData == nil then
        break
    else
        local rawRecipe = serialization.unserialize(rawRecipeData)
        local label = lookup[rawRecipe[1][1]]

        if recipes[label] == nil then
            recipes[label] = {}
        end

        recipes[label][#recipes[label] + 1] = pos
    end
    ---@diagnostic disable-next-line: undefined-field
    os.sleep(0)
end

local exec = {}

---@param label string
function exec.getRecipes(label)
    if recipes[label] == nil then
        return nil
    end

    local parsedRecipes = {}

    for i, recipeIndex in ipairs(recipes[label]) do
        parsedRecipes[i] = getRecipe(recipeIndex)
    end

    return parsedRecipes
end

---@param input string
---@param components string[]
function exec.getRecipe(input, components)
    local recipes = exec.getRecipes(input)

    if recipes == nil then
        return nil
    end

    for _, recipe in ipairs(recipes) do
        local componentCopy = {}
        for _, item in ipairs(components) do
            local label
            local size
            if type(item) == "string" then
                label = item
                size = 1
            else
                label = item.label
                size = item.size
            end

            componentCopy[label] = (componentCopy[label] or 0) + size
        end

        componentCopy[recipe.input.label] = (componentCopy[recipe.input.label] or 0) - 1

        for _, component in ipairs(recipe.components) do
            componentCopy[component.label] = (componentCopy[component.label] or 0) - 1
        end

        for _, amount in pairs(componentCopy) do
            if amount ~= 0 then
                goto continue
            end
        end

        do
            return recipe
        end

        ::continue::
    end
end

return exec
