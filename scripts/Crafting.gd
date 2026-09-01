extends Node
class_name Crafting

## Holds a list of recipes and knows how to check/consume/produce against
## an Inventory. Not tied to any world object on purpose — a future
## CraftingStation (interactable workbench, etc.) just needs to call
## CraftingUI.open()/close() when the player interacts with it; this node
## and the UI don't care what triggered that.
##
## Note on quantities: Inventory now stacks quantities of the same
## stackable item into a single slot (see ItemStack/ItemData.is_stackable()),
## so counting/consuming ingredients just delegates to Inventory's own
## count_item()/remove_item_amount() rather than scanning slots by hand.

@export var inventory_path: NodePath
@export var recipes: Array[CraftingRecipe] = []

var inventory: Inventory

signal crafted(recipe: CraftingRecipe)


func _ready() -> void:
	inventory = get_node(inventory_path)


func count_item(item: ItemData) -> int:
	return inventory.count_item(item)


func can_craft(recipe: CraftingRecipe) -> bool:
	for ingredient in recipe.ingredients:
		if count_item(ingredient.item) < ingredient.count:
			return false
	return true


func craft(recipe: CraftingRecipe) -> bool:
	if not can_craft(recipe):
		return false

	for ingredient in recipe.ingredients:
		inventory.remove_item_amount(ingredient.item, ingredient.count)

	for i in recipe.result_count:
		if not inventory.add_item(recipe.result_item):
			push_warning("Crafting: inventory full — couldn't add all of %s" % recipe.result_item.item_name)
			break

	crafted.emit(recipe)
	return true
