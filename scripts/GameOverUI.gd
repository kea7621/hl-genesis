extends CanvasLayer

## Shows on Player.died, pauses the whole tree (which freezes enemies too —
## Godot's default pause behavior handles that for free, no per-enemy code
## needed), and respawns via a full scene reload for a clean state reset.

@export var player_path: NodePath

var player: CharacterBody2D

@onready var panel: Panel = $Panel
@onready var respawn_button: Button = $Panel/VBoxContainer/RespawnButton


func _ready() -> void:
	# Must keep processing/receiving input while the tree is paused, or the
	# respawn button itself would be frozen along with everything else.
	process_mode = Node.PROCESS_MODE_ALWAYS

	player = get_node(player_path)
	player.died.connect(_on_player_died)
	respawn_button.pressed.connect(_on_respawn_pressed)
	panel.visible = false


func _on_player_died() -> void:
	panel.visible = true
	get_tree().paused = true


func _on_respawn_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
