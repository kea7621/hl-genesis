extends CanvasLayer

## Shows on Player.died, pauses the whole tree (which freezes enemies too —
## Godot's default pause behavior handles that for free, no per-enemy code
## needed). Respawn reloads the current scene for a clean state reset;
## Main Menu unpauses and sends the player back to MainMenu.tscn.

@export var player_path: NodePath
@export var main_menu_scene_path: String = "res://scenes/MainMenu.tscn"

var player: CharacterBody2D

@onready var panel: Panel = $Panel
@onready var respawn_button: Button = $Panel/VBoxContainer/RespawnButton
@onready var main_menu_button: Button = $Panel/VBoxContainer/MainMenuButton


func _ready() -> void:
	# Must keep processing/receiving input while the tree is paused, or the
	# buttons themselves would be frozen along with everything else.
	process_mode = Node.PROCESS_MODE_ALWAYS

	player = get_node(player_path)
	player.died.connect(_on_player_died)
	respawn_button.pressed.connect(_on_respawn_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	panel.visible = false


func _on_player_died() -> void:
	panel.visible = true
	get_tree().paused = true


func _on_respawn_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(main_menu_scene_path)
