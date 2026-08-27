extends Resource
class_name ItemData

## Data-only description of an item. Melee, Ranged, Crafting, Tool, and
## Armor items all use this same resource type — only the relevant export
## group matters for a given item_type. Create these as .tres files
## (Crowbar.tres, USPMatch.tres, etc.) rather than hardcoding weapon stats
## into Player.gd.

enum ItemType { MELEE, RANGED, CRAFTING, TOOL, ARMOR }
enum FireMode { SEMI_AUTO, FULL_AUTO, PUMP_ACTION }
enum EquipSlot { NONE, PRIMARY, SECONDARY, MELEE, ARMOR }

@export var item_name: String = "Item"
@export var item_type: ItemType = ItemType.RANGED
@export var icon: Texture2D  # shown on both the inventory grid AND the equip-slot icons

## Which paperdoll slot this item goes into when equipped (see
## Inventory.equip_item()). Leave NONE for items that just sit in the
## general inventory (crafting materials, etc.) and can't be equipped at
## all. This is independent of item_type — e.g. a Tool could be assigned
## to PRIMARY or SECONDARY, whichever fits your design, it isn't hardcoded
## to any one item_type.
@export var equip_slot: EquipSlot = EquipSlot.NONE

@export_group("Visuals")
@export var torso_texture: Texture2D   # swapped onto Player's Pivot/Torso when this becomes the active weapon
@export var muzzle_offset: Vector2 = Vector2(20, 0)  # where shots/melee/tool-use originate

@export_group("Ranged")
@export var fire_mode: FireMode = FireMode.SEMI_AUTO
# SEMI_AUTO (pistols): one shot per trigger pull — holding the button down
# does NOT keep firing, you have to release and press again each time.
# FULL_AUTO (SMGs/rifles): holding the button fires continuously at fire_rate.
# PUMP_ACTION (shotguns): same one-press-per-shot behavior as semi-auto —
# the distinction is really just that fire_rate is set much higher (a
# longer forced gap between shots), representing the pump/cycle time.
@export var projectile_scene: PackedScene
@export var fire_rate: float = 0.25       # seconds between shots
@export var projectile_speed: float = 700.0

@export_group("Melee")
@export var melee_range: float = 40.0
@export var melee_cooldown: float = 0.4

@export_group("Tool")
@export var use_range: float = 60.0
@export var use_cooldown: float = 0.5
# Actual hack/interact behavior lives on the target (door, forcefield, etc.)
# once those exist — this item just carries how far and how often it can
# attempt to use something. See Player._do_tool_use() for the current stub.

@export_group("Armor")
@export var armor_value: float = 0.0
# Flat damage reduction, subtracted from every hit while equipped (see
# Player.take_damage()) — not a percentage. A 5.0 armor_value turns a
# 12-damage hit into 7. Damage is clamped so it can never go negative or
# heal you.

@export_group("Shared")
@export var damage: float = 10.0  # unused by Crafting/Tool/Armor items


func get_type_label() -> String:
	match item_type:
		ItemType.MELEE:
			return "Melee"
		ItemType.RANGED:
			return "Ranged"
		ItemType.CRAFTING:
			return "Crafting Material"
		ItemType.TOOL:
			return "Tool"
		ItemType.ARMOR:
			return "Armor"
	return "Item"
