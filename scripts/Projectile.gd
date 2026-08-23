extends Area2D

## A physical projectile (not hitscan) — it travels over time, so fast-moving
## or distant targets can dodge it, and you get visible bullet tracers for free.

@export var lifetime: float = 2.0  # seconds before it despawns if it hits nothing

var speed: float = 700.0
var damage: float = 10.0
var _direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)


## Called by whoever spawns this (see Player._fire_projectile).
func launch(new_speed: float, new_damage: float) -> void:
	speed = new_speed
	damage = new_damage
	_direction = Vector2.RIGHT.rotated(rotation)


func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta


func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
