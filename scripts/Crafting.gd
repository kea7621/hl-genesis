extends Node
class_name Crafting

## Holds a list of recipes and knows how to check/consume/produce against
## an Inventory. Not tied to any world object on purpose — a future
## CraftingStation (interactable workbench, etc.) just needs to call
## CraftingUI.open()/close() when the player interacts with it; this node
## and the UI don't care what triggered that.
##
## Note on quantities: Inventory has no per-slot stack counts — each slot
## holds one ItemData reference. "3x Scrap Metal" means 3 separate slots
## each holding that same resource. count_item() below counts matching
## slots rather than reading a stack size. If you later add real stacking
## to Inventory, this is the one place that needs to change.

@export var inventory_path: NodePath
@export var recipes: Array[CraftingRecipe] = []

var inventory: Inventory

signal crafted(recipe: CraftingRecipe)


func _ready() -> void:
	inventory = get_node(inventory_path)


func count_item(item: ItemData) -> int:
	if item == null:
		return 0
	var count := 0
	for slot_item in inventory.slots:
		if slot_item == item:
			count += 1
	return count


func can_craft(recipe: CraftingRecipe) -> bool:
	for ingredient in recipe.ingredients:
		if count_item(ingredient.item) < ingredient.count:
			return false
	return true


func craft(recipe: CraftingRecipe) -> bool:
	if not can_craft(recipe):
		return false

	for ingredient in recipe.ingredients:
		_consume_item(ingredient.item, ingredient.count)

	for i in recipe.result_count:
		if not inventory.add_item(recipe.result_item):
			push_warning("Crafting: inventory full — couldn't add all of %s" % recipe.result_item.item_name)
			break

	crafted.emit(recipe)
	return true


func _consume_item(item: ItemData, amount: int) -> void:
	var removed := 0
	for i in inventory.slots.size():
		if removed >= amount:
			break
		if inventory.slots[i] == item:
			inventory.remove_item(i)
			removed += 1
