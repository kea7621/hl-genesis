extends CanvasLayer

## Toggleable crafting screen — press C to open/close for now (a future
## CraftingStation object can call open()/close() directly instead, e.g.
## when the player interacts with a workbench).

@export var inventory_path: NodePath
@export var crafting_path: NodePath

var inventory: Inventory
var crafting: Crafting
var is_open: bool = false

@onready var panel: Panel = $Panel
@onready var recipe_list: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/RecipeList


func _ready() -> void:
	inventory = get_node(inventory_path)
	crafting = get_node(crafting_path)
	inventory.inventory_changed.connect(_refresh)
	panel.visible = false
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C:
			_toggle()
		elif event.keycode == KEY_ESCAPE and is_open:
			close()


func _toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	is_open = true
	panel.visible = true
	inventory.is_ui_open = true  # reuse the same guard InventoryUI uses, blocks firing while browsing
	_refresh()


func close() -> void:
	is_open = false
	panel.visible = false
	inventory.is_ui_open = false


func _refresh() -> void:
	for child in recipe_list.get_children():
		child.queue_free()

	for recipe in crafting.recipes:
		recipe_list.add_child(_build_recipe_row(recipe))


func _build_recipe_row(recipe: CraftingRecipe) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = recipe.recipe_name
	info.add_child(name_label)

	var req_label := Label.new()
	req_label.add_theme_font_size_override("font_size", 12)
	req_label.modulate = Color(0.75, 0.75, 0.75, 1)

	var parts: Array[String] = []
	for ingredient in recipe.ingredients:
		var have := crafting.count_item(ingredient.item)
		parts.append("%s %d/%d" % [ingredient.item.item_name, have, ingredient.count])
	req_label.text = "Needs: " + ", ".join(parts)
	info.add_child(req_label)

	row.add_child(info)

	var craft_btn := Button.new()
	craft_btn.text = "Craft"
	craft_btn.custom_minimum_size = Vector2(80, 32)
	craft_btn.disabled = not crafting.can_craft(recipe)
	craft_btn.pressed.connect(func() -> void: crafting.craft(recipe))
	row.add_child(craft_btn)

	return row
