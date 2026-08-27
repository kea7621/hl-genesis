extends Control

## The game's actual entry point (set as the project's Main Scene in
## Project Settings). Main.tscn is only ever loaded from here, via Play.

@export var gameplay_scene_path: String = "res://scenes/Main.tscn"

@onready var play_button: Button = $VBoxContainer/PlayButton
@onready var quit_button: Button = $VBoxContainer/QuitButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	play_button.grab_focus()  # lets Enter/gamepad confirm start the game immediately


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(gameplay_scene_path)


func _on_quit_pressed() -> void:
	get_tree().quit()
