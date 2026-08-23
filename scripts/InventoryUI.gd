extends CanvasLayer

## A proper toggleable inventory screen: a slot grid, tooltips on hover,
## click a slot to equip it as primary. Press Tab or I to open/close,
## Escape to close. A future Crafting UI can follow this same pattern —
## read Inventory.slots, write via Inventory.add_item()/remove_item().

@export var inventory_path: NodePath
@export var columns: int = 5

var inventory: Inventory
var is_open: bool = false

@onready var panel: Panel = $Panel
@onready var grid: GridContainer = $Panel/VBoxContainer/GridContainer


func _ready() -> void:
	inventory = get_node(inventory_path)
	inventory.inventory_changed.connect(_refresh)
	inventory.equipped_changed.connect(func(_item: ItemData) -> void: _refresh())
	grid.columns = columns
	panel.visible = false
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB or event.keycode == KEY_I:
			_toggle()
		elif event.keycode == KEY_ESCAPE and is_open:
			_close()


func _toggle() -> void:
	is_open = not is_open
	panel.visible = is_open
	inventory.is_ui_open = is_open


func _close() -> void:
	is_open = false
	panel.visible = false
	inventory.is_ui_open = false


func _refresh() -> void:
	for child in grid.get_children():
		child.queue_free()

	for i in inventory.slots.size():
		var item: ItemData = inventory.slots[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(64, 64)

		if item != null:
			btn.text = item.item_name
			btn.tooltip_text = _build_tooltip(item)
			if item.icon:
				btn.icon = item.icon
			btn.modulate = Color(1, 0.9, 0.4, 1) if i == inventory.equipped_index else Color(1, 1, 1, 1)
		else:
			btn.disabled = true
			btn.modulate = Color(1, 1, 1, 0.35)

		var slot_index := i
		btn.pressed.connect(func() -> void: _on_slot_pressed(slot_index))
		grid.add_child(btn)


func _on_slot_pressed(index: int) -> void:
	if inventory.slots[index] != null:
		inventory.equip(index)


func _build_tooltip(item: ItemData) -> String:
	var lines: Array[String] = [item.item_name, "Type: %s" % item.get_type_label()]
	if item.item_type == ItemData.ItemType.CRAFTING:
		lines.append("Crafting material — used by the crafting station")
	elif item.item_type == ItemData.ItemType.TOOL:
		lines.append("Use range: %s" % item.use_range)
	else:
		lines.append("Damage: %s" % item.damage)
	return "\n".join(lines)
