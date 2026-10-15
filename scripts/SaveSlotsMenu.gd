extends Control

## A full-screen overlay listing save files, used in two modes:
##   open("save") - pick one of the 3 manual slots to write to
##   open("load") - pick any save (autosave, quicksave, slots 1-3) to load
## Each row shows the level, health, play time and when it was saved, plus a
## Delete button. Overwriting or deleting needs a second click to confirm.
##
## Built entirely in code so the exact same screen can be dropped into the
## main menu and the pause menu (both just do
## `SLOTS_MENU.new()`, add_child() it, call open(), and free it on `closed`).

signal closed

const THEME: Theme = preload("res://theme/GameTheme.tres")

var _mode: String = "load"
var _title_label: Label
var _list: VBoxContainer
var _back_button: Button
var _confirm_slot: String = ""  # slot waiting for a second click...
var _confirm_kind: String = ""  # ..."overwrite" or "delete"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # must work while the pause menu has the tree paused
	theme = THEME
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP  # clicks must not fall through to the menu underneath
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.09, 0.11, 0.97)
	style.border_color = Color(0.25, 0.75, 0.85, 1)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(1, 0.55, 0.1, 1))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title_label)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.25, 0.75, 0.85, 0.6)
	box.add_child(divider)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	box.add_child(_list)

	_back_button = Button.new()
	_back_button.text = "Back"
	_back_button.custom_minimum_size = Vector2(0, 40)
	_back_button.pressed.connect(func() -> void: closed.emit())
	box.add_child(_back_button)


func open(mode: String) -> void:
	_mode = mode
	_title_label.text = "SAVE GAME" if mode == "save" else "LOAD GAME"
	_confirm_slot = ""
	_rebuild()
	_back_button.grab_focus()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


func _rebuild() -> void:
	for child in _list.get_children():
		child.queue_free()

	var slot_ids: Array[String] = []
	if _mode == "load":
		slot_ids.append(SaveManager.AUTOSAVE)
		slot_ids.append(SaveManager.QUICKSAVE)
	slot_ids.append_array(SaveManager.MANUAL_SLOTS)

	for slot_id in slot_ids:
		_list.add_child(_build_row(slot_id))


func _build_row(slot_id: String) -> Control:
	var info: Dictionary = SaveManager.get_slot_info(slot_id)
	var exists: bool = info["exists"]

	var card := PanelContainer.new()
	card.theme_type_variation = &"RowPanel"

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)

	var name_label := Label.new()
	name_label.text = SaveManager.slot_display_name(slot_id)
	name_label.add_theme_color_override("font_color", Color(1, 0.75, 0.35, 1))
	text_box.add_child(name_label)

	var detail_label := Label.new()
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.74, 1))
	if exists:
		detail_label.text = "%s   ·   HP %d/%d   ·   %s played\n%s" % [
			info["level_name"], info["health"], info["max_health"],
			SaveManager.format_play_time(info["play_time"]), info["saved_at"]]
	else:
		detail_label.text = "Empty"
	text_box.add_child(detail_label)

	var primary := Button.new()
	primary.custom_minimum_size = Vector2(110, 36)
	primary.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _mode == "save":
		var confirming: bool = _confirm_slot == slot_id and _confirm_kind == "overwrite"
		primary.text = "Overwrite?" if confirming else "Save"
	else:
		primary.text = "Load"
		primary.disabled = not exists
	primary.pressed.connect(func() -> void: _on_primary_pressed(slot_id, exists))
	row.add_child(primary)

	var delete_button := Button.new()
	var deleting: bool = _confirm_slot == slot_id and _confirm_kind == "delete"
	delete_button.text = "Sure?" if deleting else "Delete"
	delete_button.custom_minimum_size = Vector2(80, 36)
	delete_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	delete_button.disabled = not exists
	delete_button.pressed.connect(func() -> void: _on_delete_pressed(slot_id))
	row.add_child(delete_button)

	return card


func _on_primary_pressed(slot_id: String, exists: bool) -> void:
	if _mode == "save":
		# Writing over an existing save needs a second click on the same button.
		if exists and not (_confirm_slot == slot_id and _confirm_kind == "overwrite"):
			_confirm_slot = slot_id
			_confirm_kind = "overwrite"
			_rebuild()
			return
		_confirm_slot = ""
		SaveManager.save_slot(slot_id)
		_rebuild()
	else:
		if SaveManager.load_slot(slot_id):
			closed.emit()


func _on_delete_pressed(slot_id: String) -> void:
	if _confirm_slot == slot_id and _confirm_kind == "delete":
		_confirm_slot = ""
		SaveManager.delete_slot(slot_id)
	else:
		_confirm_slot = slot_id
		_confirm_kind = "delete"
	_rebuild()
