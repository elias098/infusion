--@meta

---@alias Coordinate2D { x: number, y: number }
---@alias RawItem { [1]: string, [2]: string, [3]: number, [4]: number }
---@alias RawEssentia { [1]: string, [2]: number }
---@alias RawRecipe { [1]: RawItem, [2]: RawItem[], [3]: RawItem, [4]: RawEssentia }
---@alias Item { label: string, name: string, size: number, damage: number }
---@alias Essentia { aspect: string, amount: number }
---@alias Recipe { input: Item, components: Item[], output: Item, essentia: Essentia }
