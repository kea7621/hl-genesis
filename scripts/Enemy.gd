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
## SUSPICIOUS rather than instantly forgetting the player exists.

enum State { IDLE, SUSPICIOUS, CHASE, ATTACK }

@export_group("Movement")
@export var move_speed: float = 120.0
@export var vision_radius: float = 250.0

@export_group("Detection")
@export var suspicion_time: float = 1.5  # how long they'll investigate before giving up

@export_group("Combat")
@export var attack_range: float = 40.0
@export var attack_cooldown: float = 1.3
@export var attack_damage: float = 7.0
@export var max_health: float = 50.0

@export_group("Ranged Weapon")
@export var weapon: ItemData  # leave empty for melee (uses Combat group above instead)

var health: float
var state: State = State.IDLE
var target: Node2D = null
var last_known_position: Vector2 = Vector2.ZERO
var _suspicion_timer: float = 0.0
var _attack_timer: float = 0.0

@onready var vision_area: Area2D = $VisionArea
@onready var vision_shape: CollisionShape2D = $VisionArea/CollisionShape2D

signal died
signal health_changed(current: float, max_value: float)


func _ready() -> void:
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


func _physics_process(delta: float) -> void:
	match state:
		State.IDLE:
			velocity = Vector2.ZERO
		State.SUSPICIOUS:
			_process_suspicious(delta)
		State.CHASE:
			_process_chase()
		State.ATTACK:
			_process_attack(delta)
	move_and_slide()


func _process_suspicious(delta: float) -> void:
	# A confirmed, unobstructed sighting escalates immediately — no need to
	# finish walking to the last known position if we can already see them.
	if target != null and _has_line_of_sight(target):
		state = State.CHASE
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
		target.take_damage(attack_damage)


func _fire_at_target(item: ItemData) -> void:
	if item.projectile_scene == null:
		push_warning("Enemy: weapon '%s' has no projectile_scene assigned." % item.item_name)
		return

	var direction: Vector2 = (target.global_position - global_position).normalized()

	var proj := item.projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = global_position + direction * item.muzzle_offset.x
	proj.rotation = direction.angle()
	# The shared Projectile scene defaults to collision_mask = 2 (enemies
	# only) since that's correct for the player firing it. An enemy firing
	# the same scene needs the opposite — hit the player (layer 1), not
	# other enemies — so override it here rather than needing a second
	# duplicate projectile scene just for enemy shots.
	proj.collision_mask = 1
	if proj.has_method("launch"):
		proj.launch(item.projectile_speed, item.damage)


## Called by anything that hits this enemy — the Projectile already checks
## for this method automatically.
func take_damage(amount: float) -> void:
	health = max(health - amount, 0.0)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		die()


func die() -> void:
	died.emit()
	queue_free()


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
