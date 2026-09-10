extends Area2D
class_name CombineFabricator

## HL: Alyx-style crafting station. Starts locked (dim red) and does
## nothing if you press E on it. Equip the Multitool and use it (the
## "shoot" action — left click) while standing nearby to hack it open:
## that's just Player._do_tool_use() finding this node on the
## interactable layer and calling hack() on it, same generic mechanism
## the code already had a stub for. Once hacked it lights up (cyan) and
## stays that way — walking up and pressing E then opens the shared
## CraftingUI panel instead of doing anything itself.
##
## Registers as "nearby" with LootUI exactly the way LootContainer/
## BuildingDoor do (see LootUI.gd's comments on why it's the single
## owner of the E key) — the only wiring this node needs is
## crafting_ui_path, pointed at the CraftingUI instance in the scene.

@export var crafting_ui_path: NodePath
@export var locked_color: Color = Color(0.6, 0.15, 0.15, 1)     # dim red — unpowered
@export var unlocked_color: Color = Color(0.25, 0.85, 0.95, 1)  # cyan — hacked and live

var is_hacked: bool = false

var crafting_ui: CanvasLayer

@onready var interact_hint: Label = $InteractHint
@onready var sprite: Sprite2D = $Sprite2D

signal hacked


func _ready() -> void:
	crafting_ui = get_node(crafting_ui_path)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	interact_hint.visible = false
	sprite.modulate = locked_color
	_update_hint()


## Called by Player._do_tool_use() when the Multitool is used in range —
## this IS "hacking the fabricator" as far as the code's concerned.
## Nothing else should call this directly.
func hack() -> void:
	if is_hacked:
		return
	is_hacked = true
	sprite.modulate = unlocked_color
	_update_hint()
	hacked.emit()


## Called by LootUI's shared E-key dispatcher — never call this directly.
func interact(_player: CharacterBody2D) -> void:
	if not is_hacked:
		return
	crafting_ui.open()


func _update_hint() -> void:
	interact_hint.text = "[E] Access Fabricator" if is_hacked else "Locked — hack with Multitool"


func _on_body_entered(_body: Node) -> void:
	interact_hint.visible = true
	get_tree().call_group("loot_ui", "register_nearby_fabricator", self)


func _on_body_exited(_body: Node) -> void:
	interact_hint.visible = false
	get_tree().call_group("loot_ui", "unregister_nearby_fabricator", self)
