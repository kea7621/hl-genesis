@tool
extends Area2D

## An invisible trigger zone that shows a tutorial tip while the player
## stands inside it. Drop one anywhere in the level, give it a title and
## body text, and resize it with trigger_size — no collision shape needs
## to be added by hand (one is built at runtime from trigger_size).
##
## @tool so the zone draws as a faint cyan box with its title in the
## editor, which makes placing and sizing them against your tilemap easy.
## Nothing is drawn in the actual game.

@export var title: String = "Tip":
	set(value):
		title = value
		queue_redraw()
@export_multiline var body: String = ""
@export var trigger_size: Vector2 = Vector2(240, 200):
	set(value):
		trigger_size = value
		queue_redraw()
@export var one_shot: bool = false  # true = only ever show once, even if the player walks back through

var _used: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return

	collision_layer = 0
	collision_mask = 1  # the player's layer (wall tiles share it — filtered by group below)
	monitorable = false

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = trigger_size
	shape.shape = rect
	add_child(shape)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var rect := Rect2(-trigger_size * 0.5, trigger_size)
	draw_rect(rect, Color(0.25, 0.75, 0.85, 0.12))
	draw_rect(rect, Color(0.25, 0.75, 0.85, 0.7), false, 1.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(6, 16), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.75, 0.35, 1))


func _on_body_entered(entered: Node) -> void:
	if _used or not entered.is_in_group("player"):
		return
	get_tree().call_group("tutorial_ui", "show_hint", get_instance_id(), title, body)


func _on_body_exited(exited: Node) -> void:
	if not exited.is_in_group("player"):
		return
	get_tree().call_group("tutorial_ui", "clear_hint", get_instance_id())
	if one_shot:
		_used = true
