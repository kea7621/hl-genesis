extends Control

## The game's actual entry point (set as the project's Main Scene in
## Project Settings). Main.tscn is only ever loaded from here, via Play.

@export var gameplay_scene_path: String = "res://scenes/Main.tscn"

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var vbox: VBoxContainer = $VBoxContainer


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	play_button.grab_focus()  # lets Enter/gamepad confirm start the game immediately

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
	get_tree().change_scene_to_file(gameplay_scene_path)


func _on_quit_pressed() -> void:
	get_tree().quit()
