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
##
## Every recipe here costs nothing but Resin — the single crafting
## material in the game (HL: Alyx-style). Progression comes from how
## much Resin a recipe costs, not from a chain of intermediate parts:
## SMG is the affordable mid-game unlock, Shotgun is the expensive
## end-game one. Keep it that way — don't reintroduce sub-ingredients.

const RECIPES := [
	{
		"file": "CraftSMG",  # -> resources/recipes/CraftSMG.tres
		"name": "MP7 (SMG)",
		"ingredients": [
			{"item": "res://resources/items/Resin.tres", "count": 30},
		],
		"result": "res://resources/items/SMG.tres",
		"result_count": 1,
	},
	{
		"file": "CraftShotgun",  # -> resources/recipes/CraftShotgun.tres
		"name": "Shotgun",
		"ingredients": [
			{"item": "res://resources/items/Resin.tres", "count": 50},
		],
		"result": "res://resources/items/Shotgun.tres",
		"result_count": 1,
	},

	# Add more recipes here — copy an entry above and edit it. Keep the
	# ingredients list to just Resin at whatever count you want the item
	# to cost.
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
