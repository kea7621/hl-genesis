extends CanvasLayer

## Crafting screen — gated behind a hacked CombineFabricator now, not a
## free-standing "press C anywhere" panel. open()/close() are called by
## CombineFabricator.interact() (see that script) when the player presses
## E next to a fabricator they've already hacked with the Multitool; this
## script no longer opens itself. C/ESC still close it once it's open.

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
	if not is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_C or event.keycode == KEY_ESCAPE:
			close()


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


## Each recipe gets its own RowPanel card (rounded, bordered — see
## GameTheme.tres) rather than a bare HBoxContainer, so the scrolling list
## reads as distinct entries instead of a wall of text. Every ingredient is
## color-coded green/red per-item (have enough / don't) instead of one
## flat gray "Needs:" line, so what's actually missing jumps out instantly.
func _build_recipe_row(recipe: CraftingRecipe) -> Control:
	var can_craft: bool = crafting.can_craft(recipe)

	var card := PanelContainer.new()
	card.theme_type_variation = &"RowPanel"

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	if recipe.result_item != null and recipe.result_item.icon != null:
		var icon := TextureRect.new()
		icon.texture = recipe.result_item.icon
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = recipe.recipe_name
	if recipe.result_count > 1:
		name_label.text += " x%d" % recipe.result_count
	name_label.add_theme_font_size_override("font_size", 15)
	info.add_child(name_label)

	var req_row := HBoxContainer.new()
	req_row.add_theme_constant_override("separation", 10)
	info.add_child(req_row)

	var needs_tag := Label.new()
	needs_tag.text = "Needs:"
	needs_tag.add_theme_font_size_override("font_size", 12)
	needs_tag.add_theme_color_override("font_color", Color(0.5, 0.6, 0.62, 1))
	req_row.add_child(needs_tag)

	for ingredient in recipe.ingredients:
		var have := crafting.count_item(ingredient.item)
		var has_enough := have >= ingredient.count
		var part := Label.new()
		part.text = "%s %d/%d" % [ingredient.item.item_name, have, ingredient.count]
		part.add_theme_font_size_override("font_size", 12)
		part.add_theme_color_override(
			"font_color",
			Color(0.45, 0.85, 0.5, 1) if has_enough else Color(0.9, 0.4, 0.35, 1)
		)
		req_row.add_child(part)

	var craft_btn := Button.new()
	craft_btn.text = "Craft"
	craft_btn.custom_minimum_size = Vector2(80, 36)
	craft_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	craft_btn.disabled = not can_craft
	craft_btn.pressed.connect(func() -> void: crafting.craft(recipe))
	row.add_child(craft_btn)

	if not can_craft:
		card.modulate = Color(1, 1, 1, 0.8)

	return card
