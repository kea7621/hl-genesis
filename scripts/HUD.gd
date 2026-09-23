extends CanvasLayer

## Always-on HUD. Reads Player's existing health_changed/stamina_changed
## signals — nothing needed on the Player side beyond what's already there.
## Also reads Player's Inventory directly (public @onready var, see
## Player.gd) to keep a running Resin count on screen, HL: Alyx-style, plus
## a bottom-right "what am I holding" readout driven by active_weapon_changed.

const RESIN: ItemData = preload("res://resources/items/Resin.tres")

## Health-bar fill color shifts through these as health percentage drops,
## same "danger creeping in" read a player gets from any FPS HUD — full
## health reads calm cyan-white, low health reads alarm red.
const HEALTH_COLOR_FULL := Color(0.35, 0.85, 0.55, 1)
const HEALTH_COLOR_MID := Color(0.95, 0.75, 0.2, 1)
const HEALTH_COLOR_LOW := Color(0.85, 0.2, 0.2, 1)
const LOW_HEALTH_THRESHOLD := 0.3  # below this fraction, start the pulsing warning

@export var player_path: NodePath

var player: CharacterBody2D
var _low_health_tween: Tween

@onready var health_bar: ProgressBar = $Control/VBoxContainer/HealthRow/HealthBar
@onready var health_label: Label = $Control/VBoxContainer/HealthRow/HealthBar/HealthLabel
@onready var health_fill_style: StyleBoxFlat = health_bar.get_theme_stylebox("fill") as StyleBoxFlat
@onready var stamina_bar: ProgressBar = $Control/VBoxContainer/StaminaRow/StaminaBar
@onready var stamina_label: Label = $Control/VBoxContainer/StaminaRow/StaminaBar/StaminaLabel
@onready var resin_label: Label = $Control/VBoxContainer/ResinLabel
@onready var weapon_icon: TextureRect = $Control/WeaponPanel/WeaponRow/WeaponIcon
@onready var weapon_name_label: Label = $Control/WeaponPanel/WeaponRow/WeaponInfo/WeaponNameLabel
@onready var damage_flash: ColorRect = $Control/DamageFlash


func _ready() -> void:
	player = get_node(player_path)
	player.health_changed.connect(_on_health_changed)
	player.stamina_changed.connect(_on_stamina_changed)
	player.inventory.inventory_changed.connect(_on_inventory_changed)
	player.inventory.active_weapon_changed.connect(_on_active_weapon_changed)

	# health_changed/stamina_changed only fire on take_damage()/movement —
	# Player doesn't emit an initial value on _ready(). Set the bars from
	# whatever Player already has right now rather than waiting for the
	# first signal (same reasoning as the weapon-equip timing elsewhere).
	_on_health_changed(player.health, player.max_health)
	_on_stamina_changed(player.stamina, player.max_stamina)
	_on_inventory_changed()
	_on_active_weapon_changed(player.inventory.get_active_weapon())


func _on_health_changed(current: float, max_value: float) -> void:
	# Flash + shake-free "you got hit" feedback: only on an actual drop, not
	# on the initial _ready() call or on healing back up.
	if health_bar.value > 0.0 and current < health_bar.value:
		_flash_damage()

	health_bar.max_value = max_value
	health_bar.value = current
	health_label.text = "%d / %d" % [current, max_value]

	var fraction: float = current / max_value if max_value > 0.0 else 0.0
	health_fill_style.bg_color = _health_color(fraction)
	_update_low_health_pulse(fraction)


func _health_color(fraction: float) -> Color:
	if fraction > 0.6:
		return HEALTH_COLOR_FULL.lerp(HEALTH_COLOR_MID, (1.0 - fraction) / 0.4)
	return HEALTH_COLOR_MID.lerp(HEALTH_COLOR_LOW, 1.0 - (fraction / 0.6))


func _flash_damage() -> void:
	damage_flash.color.a = 0.28
	var tween := create_tween()
	tween.tween_property(damage_flash, "color:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)


## While health is critically low, slowly pulse the same overlay used for
## the damage flash so a player who's tabbed away from the bars still gets
## a "you are about to die" cue. Stops cleanly the moment health recovers
## past the threshold rather than leaving a stray tween running forever.
func _update_low_health_pulse(fraction: float) -> void:
	var should_pulse: bool = fraction > 0.0 and fraction <= LOW_HEALTH_THRESHOLD
	var already_pulsing: bool = _low_health_tween != null and _low_health_tween.is_valid()

	if should_pulse and not already_pulsing:
		_low_health_tween = create_tween().set_loops()
		_low_health_tween.tween_property(damage_flash, "color:a", 0.16, 0.6).set_trans(Tween.TRANS_SINE)
		_low_health_tween.tween_property(damage_flash, "color:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	elif not should_pulse and already_pulsing:
		_low_health_tween.kill()
		_low_health_tween = null
		damage_flash.color.a = 0.0


func _on_stamina_changed(current: float, max_value: float) -> void:
	stamina_bar.max_value = max_value
	stamina_bar.value = current
	stamina_label.text = "%d / %d" % [current, max_value]


func _on_inventory_changed() -> void:
	resin_label.text = "Resin: %d" % player.inventory.count_item(RESIN)


func _on_active_weapon_changed(item: ItemData) -> void:
	if item == null:
		weapon_icon.texture = null
		weapon_icon.visible = false
		weapon_name_label.text = "Unarmed"
		return

	weapon_icon.visible = item.icon != null
	weapon_icon.texture = item.icon
	weapon_name_label.text = item.item_name
