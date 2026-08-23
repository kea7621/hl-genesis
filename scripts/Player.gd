extends CharacterBody2D

## --- Movement tuning ---
@export var walk_speed: float = 180.0
@export var sprint_speed: float = 300.0
@export var acceleration: float = 1200.0
@export var friction: float = 1000.0

## --- Stamina ---
@export var max_stamina: float = 100.0
@export var stamina_drain_per_sec: float = 20.0
@export var stamina_regen_per_sec: float = 12.0
@export var stamina_regen_delay: float = 0.6  # pause after sprinting before regen kicks in

## --- Health ---
@export_group("Health")
@export var max_health: float = 100.0

var health: float
var stamina: float = max_stamina
var _regen_timer: float = 0.0
var is_sprinting: bool = false
var _attack_cooldown: float = 0.0
var is_dead: bool = false

@onready var body: Sprite2D = $Body
@onready var pivot: Node2D = $Pivot
@onready var torso: Sprite2D = $Pivot/Torso
@onready var muzzle: Marker2D = $Pivot/Muzzle
@onready var inventory: Inventory = $Inventory

signal stamina_changed(current: float, max_value: float)
signal health_changed(current: float, max_value: float)
signal died

func _ready() -> void:
	stamina = max_stamina
	health = max_health

	inventory.equipped_changed.connect(_on_weapon_equipped)
	# Inventory is a child node, so its _ready() (and initial equip()) runs
	# BEFORE this _ready() in Godot's bottom-up ready order — meaning the
	# very first equipped_changed signal fires before we've connected to it.
	# Call the handler manually once, using whatever's already equipped.
	_on_weapon_equipped(inventory.get_equipped())


func _on_weapon_equipped(item: ItemData) -> void:
	if item == null:
		return
	torso.texture = item.torso_texture
	muzzle.position = item.muzzle_offset


func _physics_process(delta: float) -> void:
	_handle_aim()
	_handle_movement(delta)
	_handle_attack(delta)
	move_and_slide()


func _handle_aim() -> void:
	var mouse_pos: Vector2 = get_global_mouse_position()
	var to_mouse: Vector2 = mouse_pos - global_position
	var facing_left: bool = to_mouse.x < 0.0

	# Body sprite: no rotation, just flip on the X axis. Use abs() so this is
	# safe to call every frame without the flip "un-flipping" itself.
	body.scale.x = -abs(body.scale.x) if facing_left else abs(body.scale.x)

	# Pivot (torso + gun) rotates freely to track the mouse at any angle...
	pivot.look_at(mouse_pos)

	# ...but flip it vertically when aiming left, otherwise the gun/torso
	# art renders upside-down past the 90°/270° mark. This is the standard
	# Gungeon/Nuclear Throne trick for 2-directional body + free-aim weapon.
	pivot.scale.y = -1.0 if facing_left else 1.0


func _handle_movement(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var wants_sprint: bool = Input.is_action_pressed("sprint") and stamina > 0.0 and input_dir.length() > 0.0
	is_sprinting = wants_sprint

	var target_speed: float = sprint_speed if is_sprinting else walk_speed
	var target_velocity: Vector2 = input_dir * target_speed

	if input_dir.length() > 0.0:
		velocity = velocity.move_toward(target_velocity, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	_update_stamina(delta)


func _update_stamina(delta: float) -> void:
	if is_sprinting:
		stamina = max(stamina - stamina_drain_per_sec * delta, 0.0)
		_regen_timer = stamina_regen_delay
	else:
		if _regen_timer > 0.0:
			_regen_timer -= delta
		else:
			stamina = min(stamina + stamina_regen_per_sec * delta, max_stamina)

	stamina_changed.emit(stamina, max_stamina)


func _handle_attack(delta: float) -> void:
	if inventory.is_ui_open:
		return

	if _attack_cooldown > 0.0:
		_attack_cooldown -= delta

	var item: ItemData = inventory.get_equipped()
	if item == null:
		return

	if not _wants_to_attack(item) or _attack_cooldown > 0.0:
		return

	match item.item_type:
		ItemData.ItemType.RANGED:
			_fire_ranged(item)
			_attack_cooldown = item.fire_rate
		ItemData.ItemType.MELEE:
			_do_melee(item)
			_attack_cooldown = item.melee_cooldown
		ItemData.ItemType.TOOL:
			_do_tool_use(item)
			_attack_cooldown = item.use_cooldown
		ItemData.ItemType.CRAFTING:
			pass  # Inventory.equip() already blocks these from being equipped;
				  # this case only exists so the match is exhaustive.


## Melee/Tool stay "hold to keep attacking" (gated by their own cooldowns
## either way). Ranged branches on fire_mode: FULL_AUTO can be held,
## SEMI_AUTO/PUMP_ACTION require a fresh press per shot.
func _wants_to_attack(item: ItemData) -> bool:
	if item.item_type != ItemData.ItemType.RANGED:
		return Input.is_action_pressed("shoot")

	if item.fire_mode == ItemData.FireMode.FULL_AUTO:
		return Input.is_action_pressed("shoot")
	return Input.is_action_just_pressed("shoot")


func _fire_ranged(item: ItemData) -> void:
	if item.projectile_scene == null:
		push_warning("Player: '%s' has no projectile_scene assigned." % item.item_name)
		return

	var proj := item.projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)
	proj.global_position = muzzle.global_position
	proj.rotation = pivot.global_rotation
	if proj.has_method("launch"):
		proj.launch(item.projectile_speed, item.damage)


func _do_melee(item: ItemData) -> void:
	# Simple overlap check in a circle around the muzzle (roughly "arm's
	# reach" in the aim direction) rather than a swing animation/hitbox —
	# good enough for a skeleton, swap for an Area2D hitbox once you have
	# swing animations timed to a specific frame.
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = item.melee_range
	query.shape = shape
	query.transform = Transform2D(0.0, muzzle.global_position)
	query.collision_mask = 2  # enemies layer — see README collision layer notes
	query.exclude = [self]

	for result in space_state.intersect_shape(query):
		var body: Node = result.collider
		if body.has_method("take_damage"):
			body.take_damage(item.damage)


func _do_tool_use(item: ItemData) -> void:
	# Stub for now — door/forcefield hacking is a later feature. This finds
	# anything nearby on the "interactable" layer (suggested: layer 3) and,
	# once those objects exist, will call something like body.hack() on
	# them. For now it just confirms the tool fired and what it found.
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = item.use_range
	query.shape = shape
	query.transform = Transform2D(0.0, muzzle.global_position)
	query.collision_mask = 4  # interactable layer — set this up when doors/forcefields exist
	query.exclude = [self]

	var results := space_state.intersect_shape(query)
	if results.is_empty():
		print("%s: nothing in range to use." % item.item_name)
		return

	for result in results:
		var body: Node = result.collider
		if body.has_method("hack"):
			body.hack()
			return
	print("%s: found something nearby, but it has no hack() method yet." % item.item_name)


## Called by enemies (and projectiles, if you later add enemy weapons) —
## keeps the same duck-typed contract the Projectile script already uses.
func take_damage(amount: float) -> void:
	if is_dead:
		return
	health = max(health - amount, 0.0)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		die()


func die() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit()
	set_physics_process(false)
