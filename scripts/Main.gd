extends Node2D

## Loot respawn: every LOOT_RESPAWN_INTERVAL seconds, every LootContainer
## found under this scene gets re-rolled against its LootTable (see
## LootContainer.roll()) and a small banner tells the player it happened.
## Containers are found by walking the tree rather than hardcoding node
## names, so dropping a new LootContainer into Main.tscn later just works
## with no changes needed here.
##
## A container the player currently has open in LootUI is skipped for that
## cycle — re-rolling it out from under them mid-browse would yank items
## off the screen while they're looking at it. It'll simply catch the next
## cycle once they close it.

const LOOT_RESPAWN_INTERVAL := 60.0  # 5 minutes
const NOTIFICATION_TEXT := "Loot has respawned"

@onready var player: CharacterBody2D = $Player

var _notify_panel: PanelContainer
var _notify_label: Label
var _notify_tween: Tween


func _ready() -> void:
	# Hide the OS cursor if you want a custom crosshair later.
	# Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	player.stamina_changed.connect(_on_player_stamina_changed)

	_setup_notification_ui()

	var loot_timer := Timer.new()
	loot_timer.wait_time = LOOT_RESPAWN_INTERVAL
	loot_timer.one_shot = false
	loot_timer.autostart = true
	loot_timer.timeout.connect(_on_loot_respawn_timeout)
	add_child(loot_timer)


func _on_player_stamina_changed(current: float, max_value: float) -> void:
	# Hook this up to a UI stamina bar later.
	pass


func _on_loot_respawn_timeout() -> void:
	var loot_ui: LootUI = get_tree().get_first_node_in_group("loot_ui")
	var respawned := 0
	for container in _find_loot_containers(self):
		if loot_ui != null and loot_ui.current_container == container:
			continue  # player's browsing this one right now — skip, catch it next cycle
		container.roll()
		respawned += 1

	if respawned > 0:
		_show_notification(NOTIFICATION_TEXT)


func _find_loot_containers(node: Node) -> Array[LootContainer]:
	var found: Array[LootContainer] = []
	for child in node.get_children():
		if child is LootContainer:
			found.append(child)
		found.append_array(_find_loot_containers(child))
	return found


## Builds a small, initially-invisible banner pinned to top-center of the
## screen, reused for every notification (just re-texted and re-tweened)
## rather than creating a new one each time.
func _setup_notification_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -140
	panel.offset_right = 140
	panel.offset_top = 16
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate = Color(1, 1, 1, 0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.05, 0.055, 0.94)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.25, 0.75, 0.85, 1)
	panel_style.content_margin_left = 14
	panel_style.content_margin_right = 14
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	layer.add_child(panel)
	_notify_panel = panel

	var label := Label.new()
	label.text = NOTIFICATION_TEXT
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.1, 1))
	panel.add_child(label)
	_notify_label = label


func _show_notification(text: String) -> void:
	_notify_label.text = text

	if _notify_tween != null and _notify_tween.is_valid():
		_notify_tween.kill()

	_notify_panel.modulate = Color(1, 1, 1, 0)
	_notify_tween = create_tween()
	_notify_tween.tween_property(_notify_panel, "modulate:a", 1.0, 0.3)
	_notify_tween.tween_interval(2.5)
	_notify_tween.tween_property(_notify_panel, "modulate:a", 0.0, 0.5)
