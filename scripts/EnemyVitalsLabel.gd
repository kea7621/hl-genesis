extends Label

## A deliberately vague health indicator — no numbers, no bar fill amount
## to read precisely, just a status word. Player gets rough feedback
## ("this thing's about to go down") without exact HP to metagame around.
##
## Sits directly under Enemy (not under any rotating node), so it just
## translates with the enemy in world space and never rotates oddly.

@export var enemy_path: NodePath = ".."  # defaults to its own parent (the Enemy)

var enemy: CharacterBody2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy = get_node(enemy_path)
	enemy.health_changed.connect(_on_health_changed)
	# No manual initial call needed here — unlike the Player/Inventory
	# weapon-equip case, this connection happens BEFORE Enemy._ready() emits
	# its first health_changed (children ready before parents), so the
	# normal signal delivers the correct starting value on its own.


func _on_health_changed(current: float, max_value: float) -> void:
	var ratio: float = current / max_value if max_value > 0.0 else 0.0

	if ratio > 0.66:
		text = "Full Vitals"
		modulate = Color(0.75, 0.8, 0.75, 0.8)
	elif ratio > 0.33:
		text = "Injured"
		modulate = Color(0.95, 0.75, 0.25, 0.9)
	else:
		text = "Critically Injured"
		modulate = Color(0.9, 0.25, 0.2, 0.95)
