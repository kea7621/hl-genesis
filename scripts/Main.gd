extends Node2D

@onready var player: CharacterBody2D = $Player

func _ready() -> void:
	# Hide the OS cursor if you want a custom crosshair later.
	# Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	player.stamina_changed.connect(_on_player_stamina_changed)


func _on_player_stamina_changed(current: float, max_value: float) -> void:
	# Hook this up to a UI stamina bar later.
	pass
