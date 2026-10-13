extends CanvasLayer

## The on-screen tutorial prompt: a small panel at the top-centre of the
## screen that shows a title and a few lines of text. Nothing here decides
## WHEN to show a tip — TutorialHint zones placed in the level call
## show_hint()/clear_hint() through the "tutorial_ui" group (same
## call_group pattern the HUD boss bar uses), so this script has no
## knowledge of any particular level.
##
## Several zones can overlap; each is tracked by its own id, and the most
## recently entered one is the one displayed. Leaving it falls back to
## whichever other zone you're still standing in.

var _panel: PanelContainer
var _title_label: Label
var _body_label: Label
var _tips: Dictionary = {}  # source id (int) -> [title, body]
var _order: Array[int] = []  # source ids, oldest first — last entry is what's shown
var _tween: Tween


func _ready() -> void:
	add_to_group("tutorial_ui")
	layer = 3
	_build_ui()
	_panel.visible = false


func show_hint(source_id: int, title: String, body: String) -> void:
	_tips[source_id] = [title, body]
	_order.erase(source_id)
	_order.append(source_id)
	_refresh()


func clear_hint(source_id: int) -> void:
	_tips.erase(source_id)
	_order.erase(source_id)
	_refresh()


func _refresh() -> void:
	if _order.is_empty():
		_panel.visible = false
		return

	var tip: Array = _tips[_order.back()]
	_title_label.text = tip[0]
	_body_label.text = tip[1]

	if not _panel.visible:
		_panel.visible = true
		_panel.modulate.a = 0.0
		if _tween != null and _tween.is_valid():
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(_panel, "modulate:a", 1.0, 0.25)


## Built in code (rather than a .tscn) because it's one panel and two
## labels — same cyan-border / amber-accent look as the HUD panels.
func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.offset_left = -250.0
	_panel.offset_right = 250.0
	_panel.offset_top = 24.0

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.09, 0.11, 0.92)
	style.border_color = Color(0.25, 0.75, 0.85, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	_panel.add_child(box)

	var tag := Label.new()
	tag.text = "TUTORIAL"
	tag.add_theme_font_size_override("font_size", 10)
	tag.add_theme_color_override("font_color", Color(0.45, 0.6, 0.62, 1))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tag)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", Color(1, 0.75, 0.35, 1))
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_title_label)

	_body_label = Label.new()
	_body_label.add_theme_font_size_override("font_size", 13)
	_body_label.add_theme_color_override("font_color", Color(0.85, 0.9, 0.9, 1))
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size = Vector2(468, 0)
	_body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_body_label)
