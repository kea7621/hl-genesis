extends Node

## Backend save/load system. Registered as an autoload singleton
## ("SaveManager") so it's reachable from anywhere without a node
## reference, and so its own _unhandled_input works regardless of which
## scene is currently loaded.
##
## Serializes to a single JSON file at user://savegame.json:
##   - Player: position, health, stamina, and full Inventory (backpack
##     slots + equip slots + active weapon), items stored by resource_path
##     so loading is exact even if two ItemData resources share a name.
##   - Loot containers: only ones explicitly opted in via the
##     "persistent_loot" group (see _serialize_loot_containers below) —
##     corpses spawned by Enemy.die() are deliberately excluded, since a
##     fresh session shouldn't reconstruct kills that didn't happen in it.
##
## No UI: quicksave is F5, quickload is F9 (see _unhandled_input). Wire a
## menu button to save_game()/load_game() later if you want one — this is
## just the backend the button would call.

const SAVE_PATH := "user://savegame.json"

signal game_saved
signal game_loaded(success: bool)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F5:
			save_game()
		elif event.keycode == KEY_F9:
			load_game()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


## Returns true on success. Fails harmlessly (with a warning, no crash) if
## there's no Player in the current scene — e.g. called from the main menu.
func save_game() -> bool:
	var player := _find_player()
	if player == null:
		push_warning("SaveManager: no Player in the current scene — nothing to save.")
		return false

	var data := {
		"version": 1,
		"timestamp": Time.get_unix_time_from_system(),
		"player": _serialize_player(player),
		"loot_containers": _serialize_loot_containers(),
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: couldn't open '%s' for writing (error %d)." % [SAVE_PATH, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	print("SaveManager: saved.")
	game_saved.emit()
	return true


## Returns true on success. Safe to call with no save file present or no
## Player in the current scene — just fails with a warning and emits
## game_loaded(false).
func load_game() -> bool:
	if not has_save():
		push_warning("SaveManager: no save file at '%s'." % SAVE_PATH)
		game_loaded.emit(false)
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("SaveManager: couldn't open '%s' for reading." % SAVE_PATH)
		game_loaded.emit(false)
		return false
	var text := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: save file is corrupt or unreadable.")
		game_loaded.emit(false)
		return false

	var player := _find_player()
	if player == null:
		push_warning("SaveManager: no Player in the current scene to load into.")
		game_loaded.emit(false)
		return false

	var data: Dictionary = parsed
	_deserialize_player(player, data.get("player", {}))
	_deserialize_loot_containers(data.get("loot_containers", {}))

	print("SaveManager: loaded.")
	game_loaded.emit(true)
	return true


func _find_player() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("Player")


# --- Player -----------------------------------------------------------

func _serialize_player(player: Node) -> Dictionary:
	var inv: Inventory = player.get("inventory")
	return {
		"position": {"x": player.global_position.x, "y": player.global_position.y},
		"health": player.health,
		"stamina": player.stamina,
		"inventory": _serialize_inventory(inv) if inv != null else {},
	}


func _deserialize_player(player: Node, data: Dictionary) -> void:
	var pos: Dictionary = data.get("position", {})
	if pos.has("x") and pos.has("y"):
		player.global_position = Vector2(pos["x"], pos["y"])

	if data.has("health"):
		player.health = float(data["health"])
		# A reload that restores positive health should un-kill a dead
		# player rather than leave them stuck in the post-death frozen
		# state (see Player.die(), which disables physics processing).
		if player.health > 0.0 and player.is_dead:
			player.is_dead = false
			player.set_physics_process(true)
		player.health_changed.emit(player.health, player.max_health)

	if data.has("stamina"):
		player.stamina = float(data["stamina"])
		player.stamina_changed.emit(player.stamina, player.max_stamina)

	var inv: Inventory = player.get("inventory")
	if inv != null and data.has("inventory"):
		_deserialize_inventory(inv, data["inventory"])


# --- Inventory ----------------------------------------------------------

func _serialize_inventory(inv: Inventory) -> Dictionary:
	var slots_data: Array = []
	for stack in inv.slots:
		if stack == null or stack.item == null:
			slots_data.append(null)
		else:
			slots_data.append({"item": stack.item.resource_path, "quantity": stack.quantity})

	var equipped_data: Dictionary = {}
	for slot_name in inv.equipped.keys():
		var item: ItemData = inv.equipped[slot_name]
		equipped_data[slot_name] = item.resource_path if item != null else ""

	return {
		"slots": slots_data,
		"equipped": equipped_data,
		"active_weapon_slot": inv.active_weapon_slot,
	}


func _deserialize_inventory(inv: Inventory, data: Dictionary) -> void:
	var slots_data: Array = data.get("slots", [])
	var new_slots: Array[ItemStack] = []
	new_slots.resize(inv.capacity)
	for i in min(slots_data.size(), inv.capacity):
		var entry: Variant = slots_data[i]
		if typeof(entry) != TYPE_DICTIONARY:
			new_slots[i] = null
			continue
		var item := _load_item(str(entry.get("item", "")))
		new_slots[i] = ItemStack.new(item, int(entry.get("quantity", 1))) if item != null else null
	inv.slots = new_slots

	var equipped_data: Dictionary = data.get("equipped", {})
	for slot_name in inv.equipped.keys():
		var path: String = str(equipped_data.get(slot_name, ""))
		var item: ItemData = _load_item(path) if path != "" else null
		inv.equipped[slot_name] = item
		inv.equip_slot_changed.emit(slot_name, item)

	inv.active_weapon_slot = str(data.get("active_weapon_slot", ""))
	inv.active_weapon_changed.emit(inv.get_active_weapon())
	inv.inventory_changed.emit()


func _load_item(path: String) -> ItemData:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as ItemData


# --- Loot containers ------------------------------------------------------
## Only containers in the "persistent_loot" group are saved/restored — add
## a static LootContainer (a table, crate, stash) to that group in the
## editor to opt it in. Enemy corpses use the same LootContainer scene but
## are spawned fresh each session and are never in that group, so they're
## excluded automatically without any special-casing here.

func _serialize_loot_containers() -> Dictionary:
	var scene := get_tree().current_scene
	if scene == null:
		return {}
	var result: Dictionary = {}
	for container in _find_loot_containers(scene):
		if not container.is_in_group("persistent_loot"):
			continue
		var key: String = str(scene.get_path_to(container))
		var contents_paths: Array = []
		for item in container.contents:
			if item != null:
				contents_paths.append(item.resource_path)
		result[key] = contents_paths
	return result


func _deserialize_loot_containers(data: Dictionary) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for container in _find_loot_containers(scene):
		if not container.is_in_group("persistent_loot"):
			continue
		var key: String = str(scene.get_path_to(container))
		if not data.has(key):
			continue
		var new_contents: Array[ItemData] = []
		for path in data[key]:
			var item := _load_item(str(path))
			if item != null:
				new_contents.append(item)
		container.contents = new_contents
		container.contents_changed.emit()


func _find_loot_containers(node: Node) -> Array[LootContainer]:
	var found: Array[LootContainer] = []
	for child in node.get_children():
		if child is LootContainer:
			found.append(child)
		found.append_array(_find_loot_containers(child))
	return found
