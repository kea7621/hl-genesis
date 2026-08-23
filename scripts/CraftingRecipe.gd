extends Resource
class_name CraftingRecipe

## A craftable result plus what it costs. Create these as .tres files —
## adding a new recipe never touches code, just a new resource with
## ingredients + a result assigned in the Inspector.

@export var recipe_name: String = "Recipe"
@export var ingredients: Array[RecipeIngredient] = []
@export var result_item: ItemData
@export var result_count: int = 1
