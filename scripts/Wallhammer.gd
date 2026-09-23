extends "res://scripts/Enemy.gd"

## Tanky boss variant: reuses Enemy's entire chase/suspicious/attack/flee
## state machine unchanged (a Wallhammer is set up with a very high
## max_health, a slow move_speed, and a high attack_damage on the base
## Enemy exports — that alone gets you "tanky with a heavy hitting
## attack", no override needed for any of it).
##
## What this script actually adds:
##  1. A frontal shield: while shield_active is true, damage arriving from
##     within shield_arc_degrees of the direction the boss is facing is
##     cut by shield_damage_reduction. See take_damage() override.
##  2. Shield coverage for allies: any other Enemy standing behind this
##     boss (within shield_protect_radius, roughly opposite the attacker —
##     see covers_position()) gets the same reduction applied to hits on
##     THEM. The base Enemy.take_damage() calls covers_position() on every
##     "boss_enemy"-group member automatically, so grunts get this for
##     free just by existing near a Wallhammer — nothing needed on their
##     end.
##  3. A punish window: swinging the melee attack (_do_attack) drops the
##     shield for shield_down_duration. The base class already calls
##     _do_attack() on its own cooldown — this just hooks the same call.
##
## Registers into the "boss_enemy" group (for the shield contract above)
## and separately "boss_health_ui" is NOT used — Main.gd finds this boss
## via "boss_enemy" directly and wires its inherited health_changed/died
## signals into HUD's boss bar. See Main.gd/HUD.gd.

@export_group("Shield")
@export var shield_arc_degrees: float = 150.0  # frontal cone (centered on current facing) that's protected
@export var shield_damage_reduction: float = 0.85  # fraction of damage blocked/passed-through while shield_active
@export var shield_protect_radius: float = 240.0  # how far behind the boss allies are still covered
@export var shield_down_duration: float = 1.1  # how long the shield stays down after a swing

@export_group("Boss")
@export var boss_display_name: String = "Wallhammer"

var shield_active: bool = true
var _shield_down_timer: float = 0.0
var _facing_direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	super._ready()
	add_to_group("boss_enemy")


func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if _shield_down_timer > 0.0:
		_shield_down_timer -= delta
		shield_active = _shield_down_timer <= 0.0

	# Track facing independently of _handle_weapon_aim() (which only runs
	# for ranged enemies) — the shield needs a facing direction whether or
	# not this boss ever carries a weapon.
	if velocity.length() > 1.0:
		_facing_direction = velocity.normalized()
	elif target != null:
		_facing_direction = (target.global_position - global_position).normalized()


## Overrides Enemy._do_attack(): identical melee hit (still goes through
## the base class's attack_damage / target.take_damage()), but the shield
## drops first — swinging a hammer two-handed means letting go of the
## shield arm for a moment.
func _do_attack() -> void:
	_shield_down_timer = shield_down_duration
	shield_active = false
	super._do_attack()


## Overrides Enemy.take_damage(): applies this boss's own frontal
## reduction before handing off to the base class, which still does
## everything else (health, death, alerting, fleeing) exactly as normal.
func take_damage(amount: float, attacker: Node2D = null) -> void:
	var final_amount: float = amount
	if shield_active and attacker != null and _is_within_shield_arc(attacker.global_position):
		final_amount = amount * (1.0 - shield_damage_reduction)
	super.take_damage(final_amount, attacker)


func _is_within_shield_arc(from_position: Vector2) -> bool:
	var to_attacker: Vector2 = (from_position - global_position).normalized()
	var angle_degrees: float = rad_to_deg(_facing_direction.angle_to(to_attacker))
	return abs(angle_degrees) <= shield_arc_degrees * 0.5


## Called by any other Enemy's _apply_shield_protection() (see Enemy.gd)
## to ask "am I covered by your shield right now?" True only if: the
## shield is actually up, `ally_position` is within shield_protect_radius,
## and the boss is roughly between the ally and the attacker (not just
## incidentally nearby on the same side).
func covers_position(ally_position: Vector2, attacker_position: Vector2) -> bool:
	if not shield_active or is_dead:
		return false
	if global_position.distance_to(ally_position) > shield_protect_radius:
		return false

	var to_ally: Vector2 = (ally_position - global_position).normalized()
	var to_attacker: Vector2 = (attacker_position - global_position).normalized()
	# Opposite-ish directions from the boss means the boss is standing
	# between them; same-ish direction means the ally is right next to
	# the attacker instead, which the shield shouldn't help with.
	return to_ally.dot(to_attacker) < -0.3
