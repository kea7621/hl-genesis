extends Area2D
class_name LootContainer

## The physical "table"/crate/body — drop one of these anywhere in your
## level with a LootTable assigned. It rolls its contents once, and the
## player walks up and presses E to open it. The actual UI lives in
## LootUI.gd, found automatically via the "loot_ui" group — same
## zero-per-instance-wiring pattern as IndoorZone/WorldDimmer elsewhere in
## this project. You only need ONE LootUI in the scene, but as many
## LootContainers as you want.

@export var display_name: String = "Container"
@export var loot_table: LootTable
@export var roll_on_ready: bool = true  # false if you want to call roll() yourself later (e.g. respawning loot)

var contents: Array[ItemData] = []
var _player_in_range: bool = false

signal contents_changed

@onready var interact_hint: Label = $InteractHint


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	interact_hint.visible = false
	if roll_on_ready:
		roll()


func roll() -> void:
	contents = loot_table.roll() if loot_table != null else []
	contents_changed.emit()


## Removes and returns the item at index, or null if out of range. Called
## by LootUI when the player takes something — not meant to be called
## directly from gameplay code elsewhere.
func take_item(index: int) -> ItemData:
	if index < 0 or index >= contents.size():
		return null
	var item: ItemData = contents[index]
	contents.remove_at(index)
	contents_changed.emit()
	return item


func _on_body_entered(_body: Node) -> void:
	_player_in_range = true
	interact_hint.visible = true
	get_tree().call_group("loot_ui", "register_nearby", self)


func _on_body_exited(_body: Node) -> void:
	_player_in_range = false
	interact_hint.visible = false
	get_tree().call_group("loot_ui", "unregister_nearby", self)
	get_tree().call_group("loot_ui", "close_if_showing", self)
