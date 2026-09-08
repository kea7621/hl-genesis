extends Area2D

## A physical projectile (not hitscan) — it travels over time, so fast-moving
## or distant targets can dodge it, and you get visible bullet tracers for free.

@export var lifetime: float = 2.0  # seconds before it despawns if it hits nothing

var speed: float = 700.0
var damage: float = 10.0
var _direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Bug fix: connecting straight to queue_free meant that if this
	# projectile already hit something and freed itself, the lifetime
	# timer would still fire later and try to call queue_free() on an
	# instance that no longer exists — a "previously freed instance"
	# error. Route through a guarded callback instead.
	get_tree().create_timer(lifetime).timeout.connect(_on_lifetime_expired)


## Called by whoever spawns this (see Player._fire_ranged / Enemy._fire_at_target).
func launch(new_speed: float, new_damage: float) -> void:
	speed = new_speed
	damage = new_damage
	_direction = Vector2.RIGHT.rotated(rotation)


func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta


func _on_body_entered(body: Node) -> void:
	if is_queued_for_deletion():
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()


func _on_lifetime_expired() -> void:
	if not is_queued_for_deletion():
		queue_free()
