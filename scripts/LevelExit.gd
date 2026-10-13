@tool
extends Area2D

## A door to the next level. Walk up and press E to load next_scene_path.
## It can be locked until a group of enemies is dead: any enemy that is
## still alive and in `lock_group` keeps it locked (Tutorial.gd puts the
## enemies under its RequiredEnemies node into that group). Leave the
## group empty/nonexistent and the exit is always open.
##
## @tool + _draw so the door is visible while you place it in the editor;
## at runtime it's drawn red while locked and cyan once it's open (no art
## asset — swap in a Sprite2D later if you like).

@export_file("*.tscn") var next_scene_path: String = "res://scenes/Main.tscn"
@export var trigger_size: Vector2 = Vector2(48, 96):
	set(value):
		trigger_size = value
		queue_redraw()
@export var prompt_text: String = "[E] Continue to the next area"
@export var locked_text: String = "Locked — defeat the remaining enemies first"
@export var lock_group: String = "tutorial_required"

var _player_inside: bool = false
var _was_locked: bool = true
var _label: Label


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return

	collision_layer = 0
	collision_mask = 1
	monitorable = false

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = trigger_size
	shape.shape = rect
	add_child(shape)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 11)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(220, 0)
	_label.position = Vector2(-110, -trigger_size.y * 0.5 - 24)
	_label.visible = false
	add_child(_label)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_was_locked = _is_locked()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var locked := _is_locked()
	if locked != _was_locked:
		_was_locked = locked
		queue_redraw()
		_update_label()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _player_inside:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if _is_locked() or next_scene_path == "":
			return
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(next_scene_path)


func _is_locked() -> bool:
	if lock_group == "":
		return false
	for node in get_tree().get_nodes_in_group(lock_group):
		if is_instance_valid(node) and not node.get("is_dead"):
			return true
	return false


func _update_label() -> void:
	if _label == null:
		return
	_label.text = locked_text if _is_locked() else prompt_text
	_label.add_theme_color_override("font_color", Color(1, 0.45, 0.35, 1) if _is_locked() else Color(0.6, 0.95, 1, 1))


func _draw() -> void:
	var locked := true if Engine.is_editor_hint() else _is_locked()
	var base := Color(0.7, 0.2, 0.2, 1) if locked else Color(0.25, 0.85, 0.95, 1)
	var rect := Rect2(-trigger_size * 0.5, trigger_size)
	draw_rect(rect, Color(base.r, base.g, base.b, 0.3))
	draw_rect(rect, base, false, 2.0)
	if Engine.is_editor_hint():
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(4, -4), "EXIT -> " + next_scene_path.get_file(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 0.75, 0.35, 1))


func _on_body_entered(entered: Node) -> void:
	if not entered.is_in_group("player"):
		return
	_player_inside = true
	_label.visible = true
	_update_label()


func _on_body_exited(exited: Node) -> void:
	if not exited.is_in_group("player"):
		return
	_player_inside = false
	_label.visible = false
