extends Area2D

## Drop one of these into every building interior, with your own
## CollisionShape2D resized to match that room's floor space. No per-zone
## setup needed beyond that — it finds WorldDimmer via the "world_dimmer"
## group automatically, so you can copy-paste this into as many buildings
## as you want without wiring a single NodePath.
##
## collision_layer should stay 0 (nothing needs to detect the zone itself)
## and collision_mask should be set to whatever layer your Player is on
## (1, per this project's convention) so only the player triggers it.


func _ready() -> void:
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)


func _on_entered(_body: Node) -> void:
	get_tree().call_group("world_dimmer", "enter_indoor")


func _on_exited(_body: Node) -> void:
	get_tree().call_group("world_dimmer", "exit_indoor")
