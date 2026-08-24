@tool
extends EditorScript

## Batch-creates/updates CraftingRecipe .tres files from the table below.
## Ingredients are embedded inline automatically (Godot saves any
## sub-resource that hasn't been saved to its own path as embedded data
## inside the parent file) — no separate RecipeIngredient.tres files are
## created, even though this script uses RecipeIngredient.new() internally.
##
## HOW TO USE:
##   1. Make sure the item(s) involved already exist (hand-made, or via
##      GenerateItems.gd — run that first if you're adding both at once).
##   2. Add an entry to RECIPES referencing those items by .tres path.
##   3. Open this file in Godot's Script tab. File > Run (Ctrl+Shift+X).
##   4. Check Output for confirmation.
##
## Still manual after running: dragging the new recipe .tres into the
## Crafting node's `Recipes` array in your scene. That's left as an
## Inspector step on purpose rather than this script touching your live
## scene file directly.

const RECIPES := [
	{
		"file": "CraftUSP",  # -> resources/recipes/CraftPipeWrench.tres
		"name": "USP Match",
		"ingredients": [
			{"item": "res://resources/items/ScrapMetal.tres", "count": 2},
			{"item": "res://resources/items/BrokenUSP.tres", "count": 1},
		],
		"result": "res://resources/items/USPMatch.tres",
		"result_count": 1,
	},
	# Add more recipes here — copy the entry above and edit it.
	# Multiple ingredients: just add more {"item": ..., "count": ...} entries.
]


func _run() -> void:
	for spec in RECIPES:
		var recipe := CraftingRecipe.new()
		recipe.recipe_name = spec.get("name", "Recipe")

		var ingredients: Array[RecipeIngredient] = []
		for ing_spec in spec.get("ingredients", []):
			var ingredient := RecipeIngredient.new()
			ingredient.item = load(ing_spec["item"]) as ItemData
			ingredient.count = ing_spec.get("count", 1)
			ingredients.append(ingredient)
		recipe.ingredients = ingredients

		recipe.result_item = load(spec["result"]) as ItemData
		recipe.result_count = spec.get("result_count", 1)

		var path := "res://resources/recipes/%s.tres" % spec["file"]
		var result := ResourceSaver.save(recipe, path)
		if result == OK:
			print("Recipe saved: ", path)
		else:
			push_error("Failed to save %s (error %d)" % [path, result])

	print("Done — %d recipe(s) processed." % RECIPES.size())
