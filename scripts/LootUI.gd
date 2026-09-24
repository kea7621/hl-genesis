extends CanvasLayer
class_name LootUI

## The single shared loot screen — AND the single owner of the E key for
## every walk-up-and-press-E interactable in the game (loot containers,
## building doors, building exit doors). LootContainer used to check for
## E itself and call open_for() directly, but since Godot delivers the
## same input event to every node's _unhandled_input, that meant a single
## press could hit BOTH LootContainer's "open" check and this script's own
## "close if already open" check in the same frame — open immediately
## followed by an invisible close. Centralizing it here avoids that
## entirely, and as a bonus lets several nearby interactables (a table
## right next to a door, say) resolve to "whichever's actually closest"
## instead of "whichever fired last".
##
## LootContainer/BuildingDoor/ExitDoor/CombineFabricator all register
## themselves as "nearby" via the "loot_ui" group while the player's in
## range, using the register_nearby_*/unregister_nearby_* methods below —
## nobody else needs a NodePath wired up.

@export var inventory_path: NodePath

var inventory: Inventory
var player: CharacterBody2D
var current_container: LootContainer
var nearby_containers: Array[LootContainer] = []
var nearby_doors: Array[BuildingDoor] = []
var nearby_exits: Array[ExitDoor] = []
var nearby_fabricators: Array[CombineFabricator] = []
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
			_interact_nearest()


## Resolves the single nearest interactable across ALL four "nearby"
## lists (containers/doors/exits/fabricators) and dispatches to whichever
## kind it turned out to be.
func _interact_nearest() -> void:
	var nearest_dist: float = INF
	var nearest_container: LootContainer = null
	var nearest_door: BuildingDoor = null
	var nearest_exit: ExitDoor = null
	var nearest_fabricator: CombineFabricator = null

	for container in nearby_containers:
		var dist: float = player.global_position.distance_to(container.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_container = container
			nearest_door = null
			nearest_exit = null
			nearest_fabricator = null

	for door in nearby_doors:
		var dist: float = player.global_position.distance_to(door.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_door = door
			nearest_container = null
			nearest_exit = null
			nearest_fabricator = null

	for exit_door in nearby_exits:
		var dist: float = player.global_position.distance_to(exit_door.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_exit = exit_door
			nearest_container = null
			nearest_door = null
			nearest_fabricator = null

	for fabricator in nearby_fabricators:
		var dist: float = player.global_position.distance_to(fabricator.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_fabricator = fabricator
			nearest_container = null
			nearest_door = null
			nearest_exit = null

	if nearest_container != null:
		open_for(nearest_container)
	elif nearest_door != null:
		nearest_door.enter(player)
	elif nearest_exit != null:
		nearest_exit.exit(player)
	elif nearest_fabricator != null:
		nearest_fabricator.interact(player)


## Called by LootContainer on body_entered — tracks it as a candidate for
## _interact_nearest() without opening anything itself.
func register_nearby(container: LootContainer) -> void:
	if not nearby_containers.has(container):
		nearby_containers.append(container)


func unregister_nearby(container: LootContainer) -> void:
	nearby_containers.erase(container)


## Called by BuildingDoor on body_entered — same "just a candidate" role
## register_nearby() plays for containers, see above.
func register_nearby_door(door: BuildingDoor) -> void:
	if not nearby_doors.has(door):
		nearby_doors.append(door)


func unregister_nearby_door(door: BuildingDoor) -> void:
	nearby_doors.erase(door)


## Called by ExitDoor on body_entered — same role, for the door(s) leading
## back outside from wherever the player currently is.
func register_nearby_exit(exit_door: ExitDoor) -> void:
	if not nearby_exits.has(exit_door):
		nearby_exits.append(exit_door)


func unregister_nearby_exit(exit_door: ExitDoor) -> void:
	nearby_exits.erase(exit_door)


## Called by CombineFabricator on body_entered — same "just a candidate"
## role register_nearby() plays for containers, see above.
func register_nearby_fabricator(fabricator: CombineFabricator) -> void:
	if not nearby_fabricators.has(fabricator):
		nearby_fabricators.append(fabricator)


func unregister_nearby_fabricator(fabricator: CombineFabricator) -> void:
	nearby_fabricators.erase(fabricator)


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

	# Group duplicate stackable items (see LootEntry.roll_count() /
	# LootTable.roll(), which can now drop several units of the same
	# stackable item into one container) into a single "5x Resin" row
	# instead of five identical ones. Non-stackable items (weapons/tools/
	# armor) are never grouped, even if two happened to land in the same
	# container — each is still its own distinct pickup.
	var seen_stackable: Dictionary = {}  # ItemData -> true, once its row has been added
	for item in current_container.contents:
		if item.is_stackable() and seen_stackable.has(item):
			continue
		if item.is_stackable():
			seen_stackable[item] = true
		item_list.add_child(_build_item_row(item))


## Same RowPanel card treatment as CraftingUI's recipe rows — an icon (when
## the item has one) plus name/type on the left, a Take button on the
## right, instead of a bare label-and-button line. `item` (not an index)
## since a row can now represent every matching copy of a stacked item at
## once — see _refresh()/_count_in_contents().
func _build_item_row(item: ItemData) -> Control:
	var count: int = _count_in_contents(item)

	var card := PanelContainer.new()
	card.theme_type_variation = &"RowPanel"

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	if item.icon != null:
		var icon := TextureRect.new()
		icon.texture = item.icon
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 0)
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = "%s  x%d" % [item.item_name, count] if count > 1 else item.item_name
	info.add_child(name_label)

	var type_label := Label.new()
	type_label.text = item.get_type_label()
	type_label.add_theme_font_size_override("font_size", 11)
	type_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.62, 1))
	info.add_child(type_label)

	var take_btn := Button.new()
	take_btn.text = "Take All" if count > 1 else "Take"
	take_btn.custom_minimum_size = Vector2(70, 32)
	take_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	take_btn.pressed.connect(func() -> void: _on_take_group_pressed(item))
	row.add_child(take_btn)

	return card


func _count_in_contents(item: ItemData) -> int:
	var count := 0
	for entry in current_container.contents:
		if entry == item:
			count += 1
	return count


## Takes every copy of `item` currently in the container in one go (the
## whole "5x Resin" stack a grouped row represents), stopping early —
## rather than losing anything — if the inventory fills up partway
## through.
func _on_take_group_pressed(item: ItemData) -> void:
	var taken_any := false
	while true:
		var index: int = current_container.contents.find(item)
		if index == -1:
			break
		var taken: ItemData = current_container.take_item(index)
		if not inventory.add_item(taken):
			current_container.contents.insert(index, taken)  # put it back, don't lose it
			push_warning("LootUI: inventory full, stopping.")
			break
		taken_any = true
	if taken_any:
		_refresh()


func _on_take_all_pressed() -> void:
	while current_container.contents.size() > 0:
		var item: ItemData = current_container.contents[0]
		if not inventory.add_item(item):
			push_warning("LootUI: inventory full, stopping Take All.")
			break
		current_container.take_item(0)
	_refresh()
