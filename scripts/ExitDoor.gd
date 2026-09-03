extends Area2D
class_name ExitDoor

## Sits inside a BuildingInterior, right at its doorway gap. Walk up and
## press E (via LootUI's shared dispatcher, exactly like every other
## interactable in this project — see LootUI.gd's comments) to step back
## outside. `interior` is set by BuildingInterior.setup() right after this
## scene is instantiated, so it's always valid by the time anyone can
## actually reach this door.

var interior: BuildingInterior

@onready var interact_hint: Label = $InteractHint


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	interact_hint.visible = false


func _on_body_entered(_body: Node) -> void:
	interact_hint.visible = true
	get_tree().call_group("loot_ui", "register_nearby_exit", self)


func _on_body_exited(_body: Node) -> void:
	interact_hint.visible = false
	get_tree().call_group("loot_ui", "unregister_nearby_exit", self)


## Called by LootUI's shared E-key dispatcher — never call this directly.
func exit(player: CharacterBody2D) -> void:
	interior.exit_player(player)
