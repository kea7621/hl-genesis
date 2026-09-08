extends CanvasLayer

## A proper toggleable inventory screen: four equip-slot icons
## (Primary/Secondary/Melee/Armor) plus the general backpack grid below.
## Click a backpack item to equip it into whichever slot its equip_slot
## points at; click an occupied equip slot to unequip it back to the
## backpack. Switching which equipped weapon is ACTIVE (what you actually
## attack with) is handled by Player.gd via number keys 1/2/3, not by
## clicking here — see Inventory.gd's comments for why those are kept
## separate. Press Tab or I to open/close, Escape to close.

@export var inventory_path: NodePath
@export var columns: int = 5

const EQUIP_SLOT_ORDER := ["primary", "secondary", "melee", "armor"]
const EQUIP_SLOT_LABELS := {"primary": "Primary", "secondary": "Secondary", "melee": "Melee", "armor": "Armor"}

var inventory: Inventory
var is_open: bool = false

@onready var panel: Panel = $Panel
@onready var equip_row: HBoxContainer = $Panel/VBoxContainer/EquipRow
@onready var grid: GridContainer = $Panel/VBoxContainer/GridContainer


func _ready() -> void:
	inventory = get_node(inventory_path)
	inventory.inventory_changed.connect(_refresh)
	inventory.equip_slot_changed.connect(func(_slot: String, _item: ItemData) -> void: _refresh())
	inventory.active_weapon_changed.connect(func(_item: ItemData) -> void: _refresh_equip_row())
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
	_refresh_equip_row()
	_refresh_grid()


func _refresh_equip_row() -> void:
	for child in equip_row.get_children():
		child.queue_free()

	for slot_name in EQUIP_SLOT_ORDER:
		equip_row.add_child(_build_equip_slot_button(slot_name))


func _build_equip_slot_button(slot_name: String) -> Control:
	var item: ItemData = inventory.equipped.get(slot_name)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(64, 64)
	btn.clip_text = true  # keep the slot fixed at 64x64 even for long names like "Salvaged Revolver" — see _refresh_grid()
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.add_theme_font_size_override("font_size", 10)

	if item != null:
		btn.tooltip_text = _build_tooltip(item)
		if item.icon:
			btn.icon = item.icon
		else:
			btn.text = item.item_name
		var is_active: bool = slot_name in Inventory.WEAPON_SLOTS and inventory.active_weapon_slot == slot_name
		btn.modulate = Color(1.0, 0.55, 0.1, 1) if is_active else Color(1, 1, 1, 1)
	else:
		btn.disabled = true
		btn.modulate = Color(1, 1, 1, 0.35)

	btn.pressed.connect(func() -> void: _on_equip_slot_pressed(slot_name))
	column.add_child(btn)

	var label := Label.new()
	label.text = EQUIP_SLOT_LABELS[slot_name]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	column.add_child(label)

	return column


## Fixed 64x64 grid of every backpack slot. Buttons fall back to showing
## item_name as text when an item has no icon assigned yet (several
## weapons/tools in this project still don't) — clip_text on the button
## keeps that name from stretching the slot (and, via GridContainer's
## per-column sizing, every other slot in that column) wider than 64px.
## The full name is still available via the tooltip.
func _refresh_grid() -> void:
	for child in grid.get_children():
		child.queue_free()

	for i in inventory.slots.size():
		var stack: ItemStack = inventory.slots[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(64, 64)
		btn.clip_text = true
		btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		btn.add_theme_font_size_override("font_size", 10)

		if stack != null:
			var item: ItemData = stack.item
			btn.tooltip_text = _build_tooltip(item, stack.quantity)
			if item.icon:
				btn.icon = item.icon
			else:
				btn.text = item.item_name
			if item.equip_slot == ItemData.EquipSlot.NONE:
				btn.modulate = Color(1, 1, 1, 0.7)  # can't be equipped — dimmed, not disabled (still viewable)
			if stack.quantity > 1:
				btn.add_child(_build_quantity_badge(stack.quantity))
		else:
			btn.disabled = true
			btn.modulate = Color(1, 1, 1, 0.35)

		var slot_index := i
		btn.pressed.connect(func() -> void: _on_grid_slot_pressed(slot_index))
		grid.add_child(btn)


## Small "xN" label pinned to a slot button's bottom-right corner, for
## stacked (quantity > 1) items. mouse_filter=IGNORE so it never steals
## the button's click. Black outline keeps it legible over any icon or
## background art the slot happens to show.
func _build_quantity_badge(quantity: int) -> Label:
	var badge := Label.new()
	badge.text = "x%d" % quantity
	badge.add_theme_font_size_override("font_size", 12)
	badge.add_theme_color_override("font_color", Color(1.0, 0.55, 0.1, 1))
	badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	badge.add_theme_constant_override("outline_size", 3)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	badge.position = Vector2(-22, -18)
	return badge


func _on_equip_slot_pressed(slot_name: String) -> void:
	inventory.unequip_slot(slot_name)


func _on_grid_slot_pressed(index: int) -> void:
	if inventory.slots[index] != null:
		inventory.equip_item(index)


func _build_tooltip(item: ItemData, quantity: int = 1) -> String:
	var lines: Array[String] = [item.item_name, "Type: %s" % item.get_type_label()]
	if quantity > 1:
		lines.append("Quantity: %d" % quantity)
	if item.item_type == ItemData.ItemType.CRAFTING:
		lines.append("Crafting material — used by the crafting station")
	elif item.item_type == ItemData.ItemType.TOOL:
		lines.append("Use range: %s" % item.use_range)
	elif item.item_type == ItemData.ItemType.ARMOR:
		lines.append("Armor: -%s damage per hit" % item.armor_value)
	else:
		lines.append("Damage: %s" % item.damage)
	return "\n".join(lines)
