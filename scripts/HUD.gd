extends CanvasLayer

## Always-on HUD. Reads Player's existing health_changed/stamina_changed
## signals — nothing needed on the Player side beyond what's already there.

@export var player_path: NodePath

var player: CharacterBody2D

@onready var health_bar: ProgressBar = $Control/VBoxContainer/HealthBar
@onready var health_label: Label = $Control/VBoxContainer/HealthBar/HealthLabel
@onready var stamina_bar: ProgressBar = $Control/VBoxContainer/StaminaBar
@onready var stamina_label: Label = $Control/VBoxContainer/StaminaBar/StaminaLabel


func _ready() -> void:
	player = get_node(player_path)
	player.health_changed.connect(_on_health_changed)
	player.stamina_changed.connect(_on_stamina_changed)

	# health_changed/stamina_changed only fire on take_damage()/movement —
	# Player doesn't emit an initial value on _ready(). Set the bars from
	# whatever Player already has right now rather than waiting for the
	# first signal (same reasoning as the weapon-equip timing elsewhere).
	_on_health_changed(player.health, player.max_health)
	_on_stamina_changed(player.stamina, player.max_stamina)


func _on_health_changed(current: float, max_value: float) -> void:
	health_bar.max_value = max_value
	health_bar.value = current
	health_label.text = "%d / %d" % [current, max_value]


func _on_stamina_changed(current: float, max_value: float) -> void:
	stamina_bar.max_value = max_value
	stamina_bar.value = current
	stamina_label.text = "%d / %d" % [current, max_value]
