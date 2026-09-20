extends Node2D
class_name BuildingInterior

## The reusable "inside of a building" shell. BuildingDoor.enter() spawns
## exactly one of these per door (lazily, kept alive after that) and
## re-skins it via setup() below — display name, which LootTable furnishes
## it, and floor/wall tint. Room shape/size is fixed in this .tscn; only
## color, name, and loot vary per building for now — see BuildingDoor.gd's
## comments for why it's parked where it is in world space.

const LOOT_CONTAINER_SCENE: PackedScene = preload("res://scenes/LootContainer.tscn")

var origin_door: BuildingDoor

@onready var title_label: Label = $TitleLabel
@onready var loot_spawn: Marker2D = $LootSpawn
@onready var exit_door: ExitDoor = $ExitDoor


func setup(display_name: String, loot_table: LootTable, door: BuildingDoor) -> void:
	origin_door = door
	exit_door.interior = self

	title_label.text = display_name


	if loot_table != null:
		var container: LootContainer = LOOT_CONTAINER_SCENE.instantiate()
		# Set every field BEFORE add_child(): add_child() runs the
		# container's _ready() synchronously, which rolls its loot table
		# immediately (roll_on_ready defaults to true) — assigning
		# loot_table/display_name/position afterward meant it always
		# rolled against a still-null loot_table and came up permanently
		# empty, no matter what was passed in here.
		container.display_name = "%s Stash" % display_name
		container.loot_table = loot_table
		container.position = loot_spawn.position
		add_child(container)


## Called by ExitDoor when the player leaves — sends them back outside,
## right where they entered. Same camera-snap reasoning as
## BuildingDoor.enter() — see its comment.
func exit_player(player: CharacterBody2D) -> void:
	if origin_door == null:
		return
	player.global_position = origin_door.get_outside_return_position()
	var camera: Camera2D = player.get_node_or_null("Camera2D")
	if camera != null:
		camera.reset_smoothing()
