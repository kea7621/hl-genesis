extends Control

## The game's actual entry point (set as the project's Main Scene in
## Project Settings). Play starts the tutorial (level 1); the tutorial's
## LevelExit then loads Main.tscn (level 2).

@export var gameplay_scene_path: String = "res://scenes/Tutorial.tscn"

const SLOTS_MENU := preload("res://scripts/SaveSlotsMenu.gd")

@onready var continue_button: Button = $VBoxContainer/ContinueButton
@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var load_button: Button = $VBoxContainer/LoadButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var vbox: VBoxContainer = $VBoxContainer


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	play_button.pressed.connect(_on_play_pressed)
	load_button.pressed.connect(_on_load_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Continue/Load only make sense once a save exists. With one, Continue
	# is the default choice (it loads whichever save is newest).
	var has_save: bool = SaveManager.has_any_save()
	continue_button.disabled = not has_save
	load_button.disabled = not has_save
	(continue_button if has_save else play_button).grab_focus()  # lets Enter/gamepad confirm immediately

	# Simple fade-in so the title screen doesn't just pop into existence —
	# the whole VBoxContainer (title + buttons) eases up and in together.
	modulate.a = 0.0
	var start_offset: Vector2 = vbox.position + Vector2(0, 14)
	var end_offset: Vector2 = vbox.position
	vbox.position = start_offset
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(vbox, "position", end_offset, 0.6).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


func _on_play_pressed() -> void:
	SaveManager.start_new_game()  # resets play time and makes a level-start autosave
	get_tree().change_scene_to_file(gameplay_scene_path)


func _on_continue_pressed() -> void:
	SaveManager.load_latest()


func _on_load_pressed() -> void:
	var menu: Control = SLOTS_MENU.new()
	add_child(menu)
	menu.open("load")
	menu.closed.connect(menu.queue_free)


func _on_quit_pressed() -> void:
	get_tree().quit()
