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

@onready var floor_sprite: Sprite2D = $Floor
@onready var wall_sprites: Array[Sprite2D] = [$Walls/North/Sprite2D, $Walls/SouthWest/Sprite2D, $Walls/SouthEast/Sprite2D, $Walls/East/Sprite2D, $Walls/West/Sprite2D]
@onready var title_label: Label = $TitleLabel
@onready var loot_spawn: Marker2D = $LootSpawn
@onready var exit_door: ExitDoor = $ExitDoor


func setup(display_name: String, loot_table: LootTable, floor_color: Color, wall_color: Color, door: BuildingDoor) -> void:
	origin_door = door
	exit_door.interior = self

	title_label.text = display_name
	floor_sprite.modulate = floor_color
	for wall_sprite in wall_sprites:
		wall_sprite.modulate = wall_color

	if loot_table != null:
		var container: LootContainer = LOOT_CONTAINER_SCENE.instantiate()
		add_child(container)
		container.display_name = "%s Stash" % display_name
		container.loot_table = loot_table
		container.position = loot_spawn.position


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
