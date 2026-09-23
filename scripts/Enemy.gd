extends CharacterBody2D

## Chase-and-attack enemy with a basic alert system and line-of-sight
## checks. Melee by default (uses attack_damage/attack_cooldown below);
## assign `weapon` to a Ranged ItemData (e.g. USPMatch.tres/SMG.tres) to
## make it fire that weapon at the player instead — same projectile, same
## damage, same fire_rate as when the player uses it, since it's literally
## the same resource.
##
## States: IDLE (nothing noticed) -> SUSPICIOUS (heard/glimpsed something,
## investigating the last known position, hasn't confirmed a target) ->
## CHASE (confirmed sighting, closing distance) -> ATTACK (in range with a
## clear shot). Losing line-of-sight while chasing/attacking drops back to
## SUSPICIOUS rather than instantly forgetting the player exists. FLEE is a
## separate branch entered directly from any state once health drops below
## flee_health_ratio (see Combat group below) — it overrides everything
## else until the enemy either breaks vision or dies.
##
## Squad awareness: confirming a sighting (entering CHASE) or taking a hit
## from an unnoticed attacker calls _alert_nearby_enemies(), which nudges
## every other enemy in the "enemies" group within alert_radius into
## SUSPICIOUS about the same target — so getting shot by one enemy in a
## group tends to bring its neighbors in too, instead of each one only
## ever reacting to its own vision cone.

enum State { IDLE, SUSPICIOUS, CHASE, ATTACK, FLEE }

@export_group("Movement")
@export var move_speed: float = 120.0
@export var vision_radius: float = 250.0

@export_group("Detection")
@export var suspicion_time: float = 1.5  # how long they'll investigate before giving up
@export var alert_radius: float = 300.0  # how far a confirmed sighting/hit alerts nearby enemies

@export_group("Combat")
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 1.3
@export var attack_damage: float = 7.0
@export var max_health: float = 50.0
@export var flee_health_ratio: float = 0.0  # 0 disables fleeing; e.g. 0.25 = flee below 25% health
@export var flee_speed_multiplier: float = 1.4

@export_group("Ranged Weapon")
@export var weapon: ItemData  # leave empty for melee (uses Combat group above instead)
@export var aim_spread_degrees: float = 5.0  # random inaccuracy per shot; 0 = laser-perfect aim
@export var strafe_speed: float = 60.0  # sideways drift while in ATTACK range; 0 disables strafing

@export_group("Loot")
@export var loot_table: LootTable  # leave empty for an enemy that drops nothing
@export var corpse_name: String = "Corpse"

const LOOT_CONTAINER_SCENE: PackedScene = preload("res://scenes/LootContainer.tscn")
const CORPSE_COLOR := Color(0.35, 0.12, 0.12, 1)  # dark red — visually distinct from tables/crates

var health: float
var state: State = State.IDLE
var target: Node2D = null
var last_known_position: Vector2 = Vector2.ZERO
var _suspicion_timer: float = 0.0
var _attack_timer: float = 0.0
var is_dead: bool = false  # guards against die() firing twice — see take_damage()
var _strafe_direction: float = 1.0  # +1/-1, flipped occasionally so ATTACK isn't a static circle-orbit
var _strafe_flip_timer: float = 0.0

@onready var vision_area: Area2D = $VisionArea
@onready var vision_shape: CollisionShape2D = $VisionArea/CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var pivot: Node2D = $Pivot
@onready var weapon_sprite: Sprite2D = $Pivot/WeaponSprite
@onready var muzzle: Marker2D = $Pivot/Muzzle

signal died
signal health_changed(current: float, max_value: float)


func _ready() -> void:
	add_to_group("enemies")  # so other enemies' _alert_nearby_enemies() can find this one
	health = max_health
	# VitalsLabel is a child, so its _ready() (where it connects to this
	# signal) runs BEFORE this one — opposite of the Player/Inventory
	# ordering elsewhere in this project. That means it's already listening
	# by the time we emit here, so this line is what gives it its correct
	# starting value (rather than showing 0/uninitialized for a frame).
	health_changed.emit(health, max_health)
	(vision_shape.shape as CircleShape2D).radius = vision_radius
	vision_area.body_entered.connect(_on_vision_entered)
	vision_area.body_exited.connect(_on_vision_exited)

	# Same trick as Player's Pivot/Torso: the "weapon sprite" IS the gun
	# art (USP.png/mp7.png/etc, same torso_texture used on the player),
	# parented under a Pivot that rotates freely to aim while the base
	# body sprite stays upright. Melee enemies (weapon == null) just never
	# show it.
	if weapon != null:
		weapon_sprite.texture = weapon.torso_texture
		muzzle.position = weapon.muzzle_offset
	weapon_sprite.visible = weapon != null


func _physics_process(delta: float) -> void:
	# Aim before acting on state, so that if _do_attack() fires this same
	# frame (from _process_attack() below), the Pivot/Muzzle are already
	# rotated toward the target rather than lagging a frame behind.
	_handle_weapon_aim()
	match state:
		State.IDLE:
			velocity = Vector2.ZERO
		State.SUSPICIOUS:
			_process_suspicious(delta)
		State.CHASE:
			_process_chase()
		State.ATTACK:
			_process_attack(delta)
		State.FLEE:
			_process_flee(delta)
	move_and_slide()


## Mirrors Player._handle_aim(): rotate the weapon Pivot to track whatever
## the enemy is currently aiming at, and flip both the body sprite and the
## Pivot vertically when facing left so the gun art doesn't render
## upside-down (the same Gungeon/Nuclear Throne trick Player.gd uses).
## Aims at the target while chasing/attacking; otherwise just faces the
## direction it's currently walking so it doesn't stand there aiming
## backwards. Holds its last facing while fully idle/stationary.
func _handle_weapon_aim() -> void:
	if weapon == null:
		return

	var aim_point: Vector2
	if target != null and (state == State.CHASE or state == State.ATTACK):
		aim_point = target.global_position
	elif velocity.length() > 1.0:
		aim_point = global_position + velocity
	else:
		return

	var facing_left: bool = aim_point.x < global_position.x
	sprite.scale.x = -abs(sprite.scale.x) if facing_left else abs(sprite.scale.x)
	pivot.look_at(aim_point)
	pivot.scale.y = -1.0 if facing_left else 1.0


func _process_suspicious(delta: float) -> void:
	# A confirmed, unobstructed sighting escalates immediately — no need to
	# finish walking to the last known position if we can already see them.
	if target != null and _has_line_of_sight(target):
		state = State.CHASE
		_alert_nearby_enemies()
		return

	_suspicion_timer -= delta
	if _suspicion_timer <= 0.0:
		state = State.IDLE
		velocity = Vector2.ZERO
		return

	var distance_to_last_known: float = global_position.distance_to(last_known_position)
	if distance_to_last_known < 8.0:
		velocity = Vector2.ZERO  # arrived at the last known spot, stand and look around
	else:
		var direction: Vector2 = (last_known_position - global_position).normalized()
		velocity = direction * move_speed * 0.6  # investigate slower than a full chase


func _process_chase() -> void:
	if target == null:
		state = State.IDLE
		return

	var distance: float = global_position.distance_to(target.global_position)
	if distance <= attack_range and _has_line_of_sight(target):
		state = State.ATTACK
		velocity = Vector2.ZERO
		return

	var direction: Vector2 = (target.global_position - global_position).normalized()
	velocity = direction * move_speed


func _process_attack(delta: float) -> void:
	if target == null:
		state = State.IDLE
		return

	# Small buffer above attack_range so it doesn't flicker between
	# chase/attack when standing right at the edge of range.
	var distance: float = global_position.distance_to(target.global_position)
	if distance > attack_range * 1.2 or not _has_line_of_sight(target):
		state = State.CHASE
		return

	# Ranged enemies drift sideways instead of standing bolt upright at
	# point-blank range — makes them a slightly harder target and reads as
	# more deliberate than a stationary turret. Melee enemies still plant
	# their feet, since they need to be in attack_range to land a hit.
	if _is_ranged() and strafe_speed > 0.0:
		_strafe_flip_timer -= delta
		if _strafe_flip_timer <= 0.0:
			_strafe_direction *= -1.0
			_strafe_flip_timer = randf_range(0.8, 1.8)
		var to_target: Vector2 = (target.global_position - global_position).normalized()
		var perpendicular: Vector2 = to_target.orthogonal()
		velocity = perpendicular * strafe_speed * _strafe_direction
	else:
		velocity = Vector2.ZERO

	if _attack_timer > 0.0:
		_attack_timer -= delta
	else:
		_do_attack()
		# Ranged enemies fire at their weapon's own pace (matching how fast
		# the player could fire the same gun) rather than the generic melee
		# attack_cooldown.
		if _is_ranged():
			_attack_timer = weapon.fire_rate
		else:
			_attack_timer = attack_cooldown


## Runs directly away from whatever's currently `target`, ignoring line of
## sight (getting shot is reason enough to run even from behind cover).
## Breaks off back to IDLE once far enough away that vision would have lost
## them anyway, rather than fleeing forever.
func _process_flee(_delta: float) -> void:
	if target == null:
		state = State.IDLE
		return

	var distance: float = global_position.distance_to(target.global_position)
	if distance > vision_radius * 1.5:
		state = State.IDLE
		target = null
		velocity = Vector2.ZERO
		return

	var away: Vector2 = (global_position - target.global_position).normalized()
	velocity = away * move_speed * flee_speed_multiplier


func _is_ranged() -> bool:
	return weapon != null and weapon.item_type == ItemData.ItemType.RANGED


## True if nothing on the "World/Obstacles" layer (suggested: layer 4,
## bitmask 8) sits between this enemy and the target. Nothing occupies
## that layer yet since there's no level geometry — add a TileMap or
## StaticBody2D walls on layer 4 and this starts blocking shots/sightings
## automatically, no further code changes needed.
func _has_line_of_sight(to_target: Node2D) -> bool:
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(global_position, to_target.global_position)
	query.collision_mask = 8  # layer 4: World/Obstacles
	query.exclude = [self]
	var result := space_state.intersect_ray(query)
	return result.is_empty()


func _do_attack() -> void:
	if target == null:
		return

	if _is_ranged():
		_fire_at_target(weapon)
	elif target.has_method("take_damage"):
		target.take_damage(attack_damage, self)


func _fire_at_target(item: ItemData) -> void:
	if item.projectile_scene == null:
		push_warning("Enemy: weapon '%s' has no projectile_scene assigned." % item.item_name)
		return

	# Pivot is already aimed at the target (see _handle_weapon_aim(), which
	# runs every physics frame the enemy is CHASE/ATTACK) — fire from the
	# same Muzzle marker the weapon sprite hangs off, exactly like
	# Player._fire_ranged() does with its own Pivot/Muzzle.
	var proj := item.projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = muzzle.global_position
	# Random inaccuracy (aim_spread_degrees) so ranged enemies aren't
	# perfect hitscan-with-travel-time — the player has a real chance to
	# juke shots at range instead of every bullet being a guaranteed hit
	# whenever the angle lines up.
	var spread: float = deg_to_rad(randf_range(-aim_spread_degrees, aim_spread_degrees) * 0.5)
	proj.rotation = pivot.global_rotation + spread
	# The shared Projectile scene defaults to collision_mask = 2 (enemies
	# only) since that's correct for the player firing it. An enemy firing
	# the same scene needs the opposite — hit the player (layer 1), not
	# other enemies — so override it here rather than needing a second
	# duplicate projectile scene just for enemy shots.
	proj.collision_mask = 1
	if proj.has_method("launch"):
		proj.launch(item.projectile_speed, item.damage, self)


## Called by anything that hits this enemy — the Projectile already checks
## for this method automatically. `attacker` is optional (older call sites
## that only pass amount still work) but when given, an IDLE/SUSPICIOUS
## enemy that gets hit immediately snaps to full awareness of whoever shot
## it instead of only reacting once its own vision cone happens to catch
## them — being shot is a much stronger signal than a glimpse.
func take_damage(amount: float, attacker: Node2D = null) -> void:
	if is_dead:
		return

	health = max(health - amount, 0.0)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		die()
		return

	if flee_health_ratio > 0.0 and health / max_health <= flee_health_ratio:
		if state != State.FLEE:
			target = attacker if attacker != null else target
			state = State.FLEE
		return

	if attacker != null and (state == State.IDLE or state == State.SUSPICIOUS):
		target = attacker
		last_known_position = attacker.global_position
		state = State.CHASE
		_alert_nearby_enemies()


## Notifies every other living enemy in the "enemies" group within
## alert_radius that this one has confirmed a target, nudging them into
## SUSPICIOUS about the same last-known position (see receive_alert()).
## Called on confirming a sighting (_process_suspicious) and on taking an
## unseen hit (take_damage) — the two moments an enemy actually "knows"
## where the threat is.
func _alert_nearby_enemies() -> void:
	if target == null:
		return
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not is_instance_valid(other) or other.is_dead:
			continue
		if global_position.distance_to(other.global_position) <= alert_radius:
			other.receive_alert(target, last_known_position)


## Called by a nearby enemy's _alert_nearby_enemies(). Doesn't override an
## enemy that's already actively engaged (CHASE/ATTACK/FLEE) with its own
## situation — only pulls IDLE/SUSPICIOUS enemies in.
func receive_alert(alert_target: Node2D, alert_position: Vector2) -> void:
	if is_dead or state == State.CHASE or state == State.ATTACK or state == State.FLEE:
		return
	target = alert_target
	last_known_position = alert_position
	state = State.SUSPICIOUS
	_suspicion_timer = suspicion_time


func die() -> void:
	# Bug fix: two hits landing in the same frame (e.g. a shotgun blast, or
	# melee + a projectile already in flight) could both bring health to 0
	# before queue_free() actually removes the node — without this guard,
	# die() ran twice, emitting `died` twice and double-firing anything
	# hooked to it (kill counters, etc.), matching the same guard Player.gd
	# already uses for take_damage()/die().
	if is_dead:
		return
	is_dead = true
	died.emit()
	_drop_loot()
	queue_free()


## Spawns a LootContainer at the death position, re-using the exact same
## walk-up-and-press-E system as every other loot table/crate/stash in the
## game (see LootContainer.gd/LootUI.gd) — a corpse is just a
## LootContainer with a different name/color and no roll_on_ready timing
## concerns, since it's created fresh at the moment of death anyway.
func _drop_loot() -> void:
	if loot_table == null:
		return

	var container: LootContainer = LOOT_CONTAINER_SCENE.instantiate()
	# Set every field BEFORE add_child() — add_child() runs the
	# container's _ready() (and therefore its loot roll) synchronously,
	# so anything assigned after that point would be too late. See the
	# identical fix in BuildingInterior.gd's setup().
	container.display_name = corpse_name
	container.loot_table = loot_table
	container.sprite_color = CORPSE_COLOR
	get_parent().add_child(container)
	container.global_position = global_position


func _on_vision_entered(body: Node) -> void:
	# VisionArea's collision_mask is set to only detect layer 1 (player),
	# so anything that enters here is assumed to be the player. Entering
	# vision doesn't jump straight to CHASE anymore — it becomes SUSPICIOUS,
	# and only escalates once _process_suspicious() confirms a clear
	# line-of-sight. Refresh (rather than ignore) if already SUSPICIOUS, so
	# repeatedly glimpsing the player resets the investigate timer.
	target = body
	if state == State.IDLE or state == State.SUSPICIOUS:
		state = State.SUSPICIOUS
		last_known_position = body.global_position
		_suspicion_timer = suspicion_time


func _on_vision_exited(body: Node) -> void:
	if body != target:
		return

	# Losing sight mid-engagement doesn't mean instantly forgetting the
	# player — go investigate their last known position instead of
	# snapping back to IDLE or standing there uselessly.
	if state == State.CHASE or state == State.ATTACK:
		state = State.SUSPICIOUS
		last_known_position = body.global_position
		_suspicion_timer = suspicion_time

	target = null
