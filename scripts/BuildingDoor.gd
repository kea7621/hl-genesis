extends Area2D
class_name BuildingDoor

## Physical door on the main map. Walk up and press E to step inside —
## the actual E-key handling lives in LootUI.gd (see its comments on why
## it's the single owner of that key; this registers as "nearby" there
## the exact same way LootContainer does, so a door standing right next
## to a loot table still resolves to "nearest wins", never a double-fire).
##
## The interior is ONE reusable BuildingInterior.tscn instance, re-skinned
## per door via the exported fields below (name/loot/colors — room shape
## itself is fixed in that scene for now). It's created lazily on first
## entry and then kept alive — parked at a fixed offset relative to THIS
## door's own position (see PARK_OFFSET), so every door's interior lands
## somewhere different automatically, with zero manual bookkeeping, and
## loot taken inside persists across visits instead of re-rolling every
## time the player walks in.

const PARK_OFFSET := Vector2(0, -4000)  # world-space, relative to this door — far enough above the map that nothing ever overlaps it
const INTERIOR_SCENE: PackedScene = preload("res://scenes/BuildingInterior.tscn")

@export var display_name: String = "Building"
@export var loot_table: LootTable
@export var floor_color: Color = Color(0.16, 0.15, 0.14, 1)
@export var wall_color: Color = Color(0.05, 0.05, 0.06, 1)

var _interior: BuildingInterior  # created lazily on first enter()

@onready var interact_hint: Label = $InteractHint


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	interact_hint.visible = false


func _on_body_entered(_body: Node) -> void:
	interact_hint.visible = true
	get_tree().call_group("loot_ui", "register_nearby_door", self)


func _on_body_exited(_body: Node) -> void:
	interact_hint.visible = false
	get_tree().call_group("loot_ui", "unregister_nearby_door", self)


## Called by LootUI's shared E-key dispatcher — never call this directly.
func enter(player: CharacterBody2D) -> void:
	if _interior == null:
		_interior = INTERIOR_SCENE.instantiate()
		get_parent().add_child(_interior)
		_interior.global_position = global_position + PARK_OFFSET
		_interior.setup(display_name, loot_table, floor_color, wall_color, self)

	player.global_position = _interior.global_position + Vector2(0, 140)  # just inside the doorway, not room-center
	_snap_camera(player)


## The teleport is a big jump (PARK_OFFSET is thousands of pixels) and
## Player's Camera2D has smoothing enabled, so without this the camera
## would visibly streak across the whole map for a moment instead of
## cutting cleanly to the interior.
func _snap_camera(player: CharacterBody2D) -> void:
	var camera: Camera2D = player.get_node_or_null("Camera2D")
	if camera != null:
		camera.reset_smoothing()


## Where the player reappears outside once they leave via ExitDoor — just
## in front of this door, so they don't immediately overlap it again.
func get_outside_return_position() -> Vector2:
	return global_position + Vector2(0, 40)
