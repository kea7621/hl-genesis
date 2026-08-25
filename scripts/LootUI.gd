extends CanvasLayer

## The single shared loot screen. Set up ONE of these in your scene with
## inventory_path pointing at the player's Inventory — every LootContainer
## finds this automatically via the "loot_ui" group, no per-container
## wiring needed.
##
## This is the ONLY place that listens for the E key. LootContainer used
## to check for E itself and call open_for() directly, but since Godot
## delivers the same input event to every node's _unhandled_input, that
## meant a single press could hit BOTH LootContainer's "open" check and
## this script's own "close if already open" check in the same frame —
## open immediately followed by an invisible close. Centralizing it here
## avoids that entirely, and as a bonus lets multiple nearby containers
## resolve to "open the nearest one" instead of "whichever fired last".

@export var inventory_path: NodePath

var inventory: Inventory
var player: Node2D
var current_container: LootContainer
var nearby_containers: Array[LootContainer] = []
var is_open: bool = false

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var take_all_button: Button = $Panel/VBoxContainer/TakeAllButton
@onready var item_list: VBoxContainer = $Panel/VBoxContainer/ScrollContainer/ItemList


func _ready() -> void:
	add_to_group("loot_ui")
	inventory = get_node(inventory_path)
	player = inventory.get_parent()  # Inventory is always a child of Player in this project
	take_all_button.pressed.connect(_on_take_all_pressed)
	panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if event.keycode == KEY_ESCAPE and is_open:
		close()
		return

	if event.keycode == KEY_E:
		if is_open:
			close()
		else:
			_open_nearest()


func _open_nearest() -> void:
	if nearby_containers.is_empty():
		return

	var nearest: LootContainer = nearby_containers[0]
	var nearest_dist: float = player.global_position.distance_to(nearest.global_position)
	for container in nearby_containers:
		var dist: float = player.global_position.distance_to(container.global_position)
		if dist < nearest_dist:
			nearest = container
			nearest_dist = dist

	open_for(nearest)


## Called by LootContainer on body_entered — tracks it as a candidate for
## _open_nearest() without opening anything itself.
func register_nearby(container: LootContainer) -> void:
	if not nearby_containers.has(container):
		nearby_containers.append(container)


func unregister_nearby(container: LootContainer) -> void:
	nearby_containers.erase(container)


func open_for(container: LootContainer) -> void:
	current_container = container
	is_open = true
	panel.visible = true
	inventory.is_ui_open = true  # same guard InventoryUI/CraftingUI use, blocks firing while browsing
	title_label.text = "Loot: %s" % container.display_name
	_refresh()


func close() -> void:
	is_open = false
	panel.visible = false
	inventory.is_ui_open = false
	current_container = null


## Called by LootContainer via group broadcast when the player walks out
## of range of whichever container is currently open.
func close_if_showing(container: LootContainer) -> void:
	if current_container == container:
		close()


func _refresh() -> void:
	for child in item_list.get_children():
		child.queue_free()

	if current_container == null:
		return

	if current_container.contents.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Empty."
		empty_label.modulate = Color(0.7, 0.7, 0.7, 1)
		item_list.add_child(empty_label)
		return

	for i in current_container.contents.size():
		item_list.add_child(_build_item_row(i))


func _build_item_row(index: int) -> Control:
	var item: ItemData = current_container.contents[index]

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_label := Label.new()
	name_label.text = item.item_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	var take_btn := Button.new()
	take_btn.text = "Take"
	take_btn.custom_minimum_size = Vector2(70, 32)
	take_btn.pressed.connect(func() -> void: _on_take_pressed(index))
	row.add_child(take_btn)

	return row


func _on_take_pressed(index: int) -> void:
	var item: ItemData = current_container.take_item(index)
	if item == null:
		return
	if not inventory.add_item(item):
		push_warning("LootUI: inventory full, couldn't take %s" % item.item_name)
		current_container.contents.insert(index, item)  # put it back, don't lose it
		return
	_refresh()


func _on_take_all_pressed() -> void:
	while current_container.contents.size() > 0:
		var item: ItemData = current_container.contents[0]
		if not inventory.add_item(item):
			push_warning("LootUI: inventory full, stopping Take All.")
			break
		current_container.take_item(0)
	_refresh()
