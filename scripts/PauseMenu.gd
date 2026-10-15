extends CanvasLayer

## Pause menu, registered as an autoload so every level gets it without
## adding anything to its scene. Esc opens/closes it during gameplay:
##   Resume / Save Game / Load Game / Main Menu / Quit
##
## It only reacts when there's a living player in the current scene (so
## never on the main menu) and when no other panel is using Esc: the
## inventory, crafting and loot screens already close themselves on Esc,
## and Player.inventory.is_ui_open tells us when one of them is showing.

const SLOTS_MENU := preload("res://scripts/SaveSlotsMenu.gd")
const THEME: Theme = preload("res://theme/GameTheme.tres")
const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"

var _root: Control
var _resume_button: Button
var _slots_menu: Control = null
var _is_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # has to keep working while it holds the tree paused
	layer = 60
	_build_ui()
	_root.visible = false
	SaveManager.load_started.connect(_on_load_started)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _slots_menu != null:
		return  # the save/load screen handles its own Esc

	if _is_open:
		_close()
		get_viewport().set_input_as_handled()
		return

	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null or player.is_dead or get_tree().paused:
		return  # no player (menus), dead (game-over screen is up), or something else has already paused
	if player.inventory.is_ui_open:
		return  # Esc belongs to the open inventory/crafting/loot panel — let it close that
	_open()
	get_viewport().set_input_as_handled()


func _open() -> void:
	_is_open = true
	get_tree().paused = true
	_root.visible = true
	_resume_button.grab_focus()


func _close() -> void:
	_is_open = false
	_root.visible = false
	get_tree().paused = false


func _open_slots(mode: String) -> void:
	_slots_menu = SLOTS_MENU.new()
	_root.add_child(_slots_menu)
	_slots_menu.open(mode)
	_slots_menu.closed.connect(_on_slots_closed)


func _on_slots_closed() -> void:
	if _slots_menu != null:
		_slots_menu.queue_free()
		_slots_menu = null
	if _is_open:
		_resume_button.grab_focus()


func _on_load_started() -> void:
	# A load swaps the whole level and SaveManager unpauses the tree itself —
	# just get this menu out of the way.
	_is_open = false
	_root.visible = false
	if _slots_menu != null:
		_slots_menu.queue_free()
		_slots_menu = null


func _on_main_menu_pressed() -> void:
	_close()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _build_ui() -> void:
	_root = Control.new()
	_root.theme = THEME
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.09, 0.11, 0.97)
	style.border_color = Color(0.25, 0.75, 0.85, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 20
	style.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.55, 0.1, 1))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.25, 0.75, 0.85, 0.6)
	box.add_child(divider)

	_resume_button = _make_button("Resume", box)
	_resume_button.pressed.connect(_close)
	_make_button("Save Game", box).pressed.connect(_open_slots.bind("save"))
	_make_button("Load Game", box).pressed.connect(_open_slots.bind("load"))
	_make_button("Main Menu", box).pressed.connect(_on_main_menu_pressed)
	_make_button("Quit Game", box).pressed.connect(func() -> void: get_tree().quit())


func _make_button(text: String, parent: Control) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	parent.add_child(button)
	return button
