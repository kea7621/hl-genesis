extends Node

## The game's save system. Registered as an autoload so it survives scene
## changes and can be called from anywhere (menus, levels, the pause menu).
##
## FILES: every save is one human-readable JSON file in user://saves/:
##   autosave.json, quicksave.json, slot_1.json, slot_2.json, slot_3.json
## Each file records which level (scene) you were in, how long you've
## played, when it was saved, the player (position, health, stamina,
## inventory, loaded ammo) and the state of the world (which enemies are
## still alive and how hurt they are, what's left in loot containers,
## bodies/dropped items on the ground, opened building stashes, and hacked
## fabricators).
##
## LOADING: always reloads the saved level fresh and then applies the saved
## state on top of it (see _run_load). That one path handles loading from
## the main menu, from the pause menu, from the game-over screen, and
## across levels, and it means a load can never leave stray leftovers from
## whatever was on screen before.
##
## WHAT TRIGGERS A SAVE: the pause menu / main menu slot screens (SaveSlotsMenu),
## F5 (quicksave), F9 (load quicksave), an autosave when you arrive in a new
## level (LevelExit sets autosave_on_level_start), and a timed autosave.

const SAVE_DIR := "user://saves/"
const SAVE_VERSION := 2
const QUICKSAVE := "quicksave"
const AUTOSAVE := "autosave"
const MANUAL_SLOTS: Array[String] = ["slot_1", "slot_2", "slot_3"]
const AUTOSAVE_INTERVAL := 120.0  # seconds between timed autosaves

## Friendly level names shown on the save slots. Add new levels here.
const LEVEL_NAMES := {
	"res://scenes/Tutorial.tscn": "Tutorial",
	"res://scenes/Main.tscn": "Level 2",
}

const LOOT_CONTAINER_SCENE: PackedScene = preload("res://scenes/LootContainer.tscn")

signal saved(slot_id: String)
signal load_started
signal load_finished(success: bool)

var play_time: float = 0.0  # seconds spent in gameplay, carried inside save files
var autosave_on_level_start: bool = false  # set by LevelExit / start_new_game(); consumed by on_level_ready()

var _loading: bool = false
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # toasts must work while the pause menu has the tree paused; gameplay-only logic checks get_tree().paused itself
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_build_toast()

	var timer := Timer.new()
	timer.wait_time = AUTOSAVE_INTERVAL
	timer.autostart = true
	timer.timeout.connect(_on_autosave_timer)
	add_child(timer)


func _process(delta: float) -> void:
	if not get_tree().paused and is_gameplay_active():
		play_time += delta


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F5:
		quicksave()
	elif event.keycode == KEY_F9:
		if has_save(QUICKSAVE):
			load_slot(QUICKSAVE)
		else:
			toast("No quicksave yet (F5 to make one)")


# --- Public API --------------------------------------------------------

func slot_path(slot_id: String) -> String:
	return SAVE_DIR + slot_id + ".json"


func slot_display_name(slot_id: String) -> String:
	if slot_id == AUTOSAVE:
		return "Autosave"
	if slot_id == QUICKSAVE:
		return "Quicksave"
	return "Slot " + slot_id.trim_prefix("slot_")


func get_level_name(scene_path: String) -> String:
	return LEVEL_NAMES.get(scene_path, scene_path.get_file().get_basename())


func format_play_time(seconds: float) -> String:
	var total: int = int(seconds)
	var hours: int = floori(total / 3600.0)
	var minutes: int = floori((total % 3600) / 60.0)
	var secs: int = total % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, secs]
	return "%d:%02d" % [minutes, secs]


func has_save(slot_id: String) -> bool:
	return FileAccess.file_exists(slot_path(slot_id))


func has_any_save() -> bool:
	return get_latest_slot() != ""


func delete_slot(slot_id: String) -> void:
	if has_save(slot_id):
		DirAccess.remove_absolute(slot_path(slot_id))


## Summary used by the slot list UI. {"exists": false} for empty slots.
func get_slot_info(slot_id: String) -> Dictionary:
	var data := _read_slot(slot_id)
	if data.is_empty():
		return {"exists": false}
	var player_data: Dictionary = data.get("player", {})
	return {
		"exists": true,
		"level_name": get_level_name(str(data.get("scene", ""))),
		"health": float(player_data.get("health", 0.0)),
		"max_health": float(player_data.get("max_health", 100.0)),
		"play_time": float(data.get("play_time", 0.0)),
		"saved_at": str(data.get("saved_at", "")),
		"timestamp": float(data.get("timestamp", 0.0)),
	}


## The most recently written save of any kind ("" if there are none) —
## what the Continue button loads.
func get_latest_slot() -> String:
	var best := ""
	var best_time := -1.0
	var all_slots: Array[String] = [AUTOSAVE, QUICKSAVE]
	all_slots.append_array(MANUAL_SLOTS)
	for slot_id in all_slots:
		var info := get_slot_info(slot_id)
		if info["exists"] and info["timestamp"] > best_time:
			best_time = info["timestamp"]
			best = slot_id
	return best


## Call when starting a brand-new game from the main menu.
func start_new_game() -> void:
	play_time = 0.0
	autosave_on_level_start = true


## Called by Main.gd (and so every level that extends it) at the end of
## its _ready(). Makes a checkpoint when the player has just arrived in a
## level via a LevelExit or a new game — but NOT on a respawn/reload or
## while a load is in progress, so those can't overwrite a good autosave.
func on_level_ready() -> void:
	if _loading or not autosave_on_level_start:
		return
	autosave_on_level_start = false
	autosave.call_deferred()


func quicksave() -> bool:
	return save_slot(QUICKSAVE)


func autosave() -> bool:
	return save_slot(AUTOSAVE, true)


func is_gameplay_active() -> bool:
	var player := _find_player()
	return player != null and not player.is_dead


## Writes the current game to `slot_id`. Returns true on success. `quiet`
## swaps the "Saved: Slot 1" message for a small "Autosaved" one.
func save_slot(slot_id: String, quiet: bool = false) -> bool:
	if _loading:
		return false
	var player := _find_player()
	var scene := get_tree().current_scene
	if player == null or scene == null or scene.scene_file_path == "" or player.is_dead:
		if not quiet:
			toast("Can't save right now")
		return false

	var data := {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"scene": scene.scene_file_path,
		"play_time": play_time,
		"player": _serialize_player(player),
		"world": _serialize_world(scene),
	}

	var file := FileAccess.open(slot_path(slot_id), FileAccess.WRITE)
	if file == null:
		push_warning("SaveManager: couldn't write '%s' (error %d)." % [slot_path(slot_id), FileAccess.get_open_error()])
		toast("Save failed")
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

	saved.emit(slot_id)
	toast("Autosaved" if quiet else "Saved: " + slot_display_name(slot_id))
	return true


## Starts loading `slot_id`. Returns false straight away if there's nothing
## valid to load; otherwise the load continues over the next few frames
## (a level has to be reloaded first) and load_finished fires at the end.
func load_slot(slot_id: String) -> bool:
	if _loading:
		return false
	var data := _read_slot(slot_id)
	var scene_path := str(data.get("scene", ""))
	if data.is_empty() or scene_path == "" or not ResourceLoader.exists(scene_path):
		toast("Couldn't load " + slot_display_name(slot_id))
		return false

	_loading = true
	autosave_on_level_start = false
	load_started.emit()
	_run_load(data)  # coroutine, deliberately not awaited — whoever called us (a menu) is about to be freed by the scene change
	return true


func load_latest() -> bool:
	var slot_id := get_latest_slot()
	return slot_id != "" and load_slot(slot_id)


func toast(text: String) -> void:
	_toast_label.text = text
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_panel.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.5)


# --- Loading ---------------------------------------------------------------

func _run_load(data: Dictionary) -> void:
	play_time = float(data.get("play_time", 0.0))
	get_tree().paused = false

	var old_scene := get_tree().current_scene
	get_tree().change_scene_to_file(str(data["scene"]))

	# change_scene_to_file swaps scenes at the end of the frame, so wait
	# until the NEW scene (not the old one, which can be the same file when
	# reloading the level you're already in) is in and ready.
	var fresh: Node = null
	for i in 30:
		await get_tree().process_frame
		var current := get_tree().current_scene
		if current != null and current != old_scene and current.is_node_ready():
			fresh = current
			break

	if fresh == null:
		push_warning("SaveManager: level failed to load, aborting.")
		_loading = false
		load_finished.emit(false)
		return

	await get_tree().process_frame  # let anything the level does in a deferred _ready finish first
	_apply_world(fresh, data)
	_loading = false
	load_finished.emit(true)
	toast("Game loaded")


func _apply_world(scene: Node, data: Dictionary) -> void:
	var player := _find_player()
	if player == null:
		push_warning("SaveManager: no player in the loaded level.")
		return

	var world: Dictionary = data.get("world", {})
	# Doors first, so a saved building stash exists before anything refers to it.
	_apply_doors(scene, world.get("doors", {}))
	_apply_enemies(scene, world.get("enemies", {}))
	_apply_static_containers(scene, world.get("loot_containers", {}))
	_apply_dynamic_containers(scene, world.get("dynamic_loot", []))
	_apply_fabricators(scene, world.get("fabricators", {}))

	_deserialize_player(player, data.get("player", {}))


# --- Reading / writing files --------------------------------------------------

func _read_slot(slot_id: String) -> Dictionary:
	if not has_save(slot_id):
		return {}
	var file := FileAccess.open(slot_path(slot_id), FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}  # corrupt or empty file
	var dict: Dictionary = parsed
	if int(dict.get("version", 0)) != SAVE_VERSION:
		return {}  # written by an incompatible version of the game
	return dict


func _find_player() -> Node:
	var player: Node = get_tree().get_first_node_in_group("player")
	return player if is_instance_valid(player) else null


func _on_autosave_timer() -> void:
	if get_tree().paused or _loading or not is_gameplay_active():
		return
	var player := _find_player()
	if player.inventory.is_ui_open:
		return  # don't snapshot mid-menu (the inventory could be half-rearranged)
	autosave()


# --- Player ---------------------------------------------------------------------

func _serialize_player(player: Node) -> Dictionary:
	var inv: Inventory = player.get("inventory")
	return {
		"position": {"x": player.global_position.x, "y": player.global_position.y},
		"health": player.health,
		"max_health": player.max_health,
		"stamina": player.stamina,
		"ammo": player.get_ammo_save_data(),
		"inventory": _serialize_inventory(inv) if inv != null else {},
	}


func _deserialize_player(player: Node, data: Dictionary) -> void:
	# Ammo first, so the HUD refresh the inventory restore triggers below
	# already sees the right magazine counts.
	player.load_ammo_save_data(data.get("ammo", {}))

	if data.has("health"):
		player.health = float(data["health"])
		player.health_changed.emit(player.health, player.max_health)
	if data.has("stamina"):
		player.stamina = float(data["stamina"])
		player.stamina_changed.emit(player.stamina, player.max_stamina)

	var inv: Inventory = player.get("inventory")
	if inv != null and data.has("inventory"):
		_deserialize_inventory(inv, data["inventory"])

	# Position last: if the player was standing inside a building, that
	# interior was recreated by _apply_doors and is now there to stand in.
	var pos: Dictionary = data.get("position", {})
	if pos.has("x") and pos.has("y"):
		player.global_position = Vector2(pos["x"], pos["y"])
		var camera: Camera2D = player.get_node_or_null("Camera2D")
		if camera != null:
			camera.reset_smoothing()  # otherwise the smoothed camera visibly streaks across the map


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


# --- World: serialize ----------------------------------------------------------

func _serialize_world(scene: Node) -> Dictionary:
	return {
		"enemies": _serialize_enemies(scene),
		"loot_containers": _serialize_static_containers(scene),
		"dynamic_loot": _serialize_dynamic_containers(scene),
		"doors": _serialize_doors(scene),
		"fabricators": _serialize_fabricators(scene),
	}


## Living enemies only, keyed by their path in the level. On load, an enemy
## that's in the level but NOT in this list is one that was killed — it's
## removed (see _apply_enemies).
func _serialize_enemies(scene: Node) -> Dictionary:
	var result := {}
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_dead or not scene.is_ancestor_of(enemy):
			continue
		result[str(scene.get_path_to(enemy))] = {
			"x": enemy.global_position.x,
			"y": enemy.global_position.y,
			"health": enemy.health,
		}
	return result


## Containers placed in the level itself (crates, stashes). Corpses and
## dropped items are "dynamic_loot" and saved separately; the stash inside a
## building belongs to its door (see _serialize_doors).
func _serialize_static_containers(scene: Node) -> Dictionary:
	var result := {}
	for container in _find_containers(scene):
		if container.is_in_group("dynamic_loot") or container.get_parent() is BuildingInterior:
			continue
		result[str(scene.get_path_to(container))] = _contents_to_paths(container)
	return result


## Bodies and items the player dropped — they only exist because of
## something that happened in play, so they're recreated from scratch on load.
func _serialize_dynamic_containers(scene: Node) -> Array:
	var result: Array = []
	for container in get_tree().get_nodes_in_group("dynamic_loot"):
		if not is_instance_valid(container) or not scene.is_ancestor_of(container) or container.contents.is_empty():
			continue
		var c: Color = container.sprite_color
		result.append({
			"name": container.display_name,
			"x": container.global_position.x,
			"y": container.global_position.y,
			"color": [c.r, c.g, c.b, c.a],
			"contents": _contents_to_paths(container),
		})
	return result


## Only doors whose building has actually been entered have anything to save.
func _serialize_doors(scene: Node) -> Dictionary:
	var result := {}
	for door in _find_nodes(scene, func(n: Node) -> bool: return n is BuildingDoor):
		var interior: BuildingInterior = door.get_interior()
		if interior == null:
			continue
		var stash := _interior_container(interior)
		result[str(scene.get_path_to(door))] = {"contents": _contents_to_paths(stash) if stash != null else []}
	return result


func _serialize_fabricators(scene: Node) -> Dictionary:
	var result := {}
	for fab in _find_nodes(scene, func(n: Node) -> bool: return n is CombineFabricator):
		result[str(scene.get_path_to(fab))] = fab.is_hacked
	return result


# --- World: apply ---------------------------------------------------------------

func _apply_enemies(scene: Node, saved: Dictionary) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not scene.is_ancestor_of(enemy):
			continue
		var key := str(scene.get_path_to(enemy))
		if saved.has(key):
			var d: Dictionary = saved[key]
			enemy.global_position = Vector2(d["x"], d["y"])
			enemy.health = float(d["health"])
			enemy.health_changed.emit(enemy.health, enemy.max_health)
		else:
			# Was dead when the game was saved. Mark it dead first so
			# anything watching it (e.g. a locked exit) reacts immediately
			# instead of waiting for the node to actually be freed.
			enemy.is_dead = true
			enemy.remove_from_group("enemies")
			enemy.queue_free()


func _apply_static_containers(scene: Node, saved: Dictionary) -> void:
	for container in _find_containers(scene):
		if container.is_in_group("dynamic_loot") or container.get_parent() is BuildingInterior:
			continue
		var key := str(scene.get_path_to(container))
		if saved.has(key):
			_set_contents(container, saved[key])


func _apply_dynamic_containers(scene: Node, saved: Array) -> void:
	for entry in saved:
		var container: LootContainer = LOOT_CONTAINER_SCENE.instantiate()
		# Everything is set BEFORE add_child(), which runs _ready() immediately.
		container.display_name = str(entry.get("name", "Container"))
		container.roll_on_ready = false
		var col: Array = entry.get("color", [0.45, 0.32, 0.2, 1.0])
		container.sprite_color = Color(col[0], col[1], col[2], col[3])
		container.add_to_group("dynamic_loot")
		scene.add_child(container)
		container.global_position = Vector2(entry["x"], entry["y"])
		_set_contents(container, entry.get("contents", []))


func _apply_doors(scene: Node, saved: Dictionary) -> void:
	for door in _find_nodes(scene, func(n: Node) -> bool: return n is BuildingDoor):
		var key := str(scene.get_path_to(door))
		if not saved.has(key):
			continue
		door.ensure_interior()  # builds the interior (without moving the player)
		var stash := _interior_container(door.get_interior())
		if stash != null:
			_set_contents(stash, saved[key].get("contents", []))


func _apply_fabricators(scene: Node, saved: Dictionary) -> void:
	for fab in _find_nodes(scene, func(n: Node) -> bool: return n is CombineFabricator):
		if saved.get(str(scene.get_path_to(fab)), false):
			fab.hack()


# --- Small helpers -----------------------------------------------------------------

func _find_nodes(root: Node, test: Callable) -> Array:
	var out: Array = []
	_collect_nodes(root, test, out)
	return out


func _collect_nodes(node: Node, test: Callable, out: Array) -> void:
	for child in node.get_children():
		if test.call(child):
			out.append(child)
		_collect_nodes(child, test, out)


func _find_containers(root: Node) -> Array:
	return _find_nodes(root, func(n: Node) -> bool: return n is LootContainer)


func _interior_container(interior: BuildingInterior) -> LootContainer:
	if interior == null:
		return null
	for child in interior.get_children():
		if child is LootContainer:
			return child
	return null


func _contents_to_paths(container: LootContainer) -> Array:
	var paths: Array = []
	for item in container.contents:
		if item != null:
			paths.append(item.resource_path)
	return paths


func _set_contents(container: LootContainer, paths: Array) -> void:
	var items: Array[ItemData] = []
	for path in paths:
		var item := _load_item(str(path))
		if item != null:
			items.append(item)
	container.contents = items
	container.contents_changed.emit()


# --- "Saved" / "Loaded" pop-up ---------------------------------------------------------

func _build_toast() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	_toast_panel = PanelContainer.new()
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast_panel.offset_top = -40.0
	_toast_panel.offset_bottom = -40.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.09, 0.11, 0.92)
	style.border_color = Color(0.25, 0.75, 0.85, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_toast_panel.add_theme_stylebox_override("panel", style)
	layer.add_child(_toast_panel)

	_toast_label = Label.new()
	_toast_label.add_theme_font_size_override("font_size", 14)
	_toast_label.add_theme_color_override("font_color", Color(1, 0.75, 0.35, 1))
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_child(_toast_label)
	_toast_panel.modulate.a = 0.0
