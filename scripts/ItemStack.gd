extends RefCounted
class_name ItemStack

## One occupied inventory slot: a reference to the shared ItemData resource
## plus how many units of it this slot holds. ItemData itself stays a plain
## data resource (shared by every stack of that item, and by loot tables/
## recipes) — the quantity lives here, per-slot, instead.
##
## Only ItemData.is_stackable() items ever have quantity > 1 (see
## Inventory.add_item()); non-stackable items (weapons/tools/armor) always
## sit alone in a slot with quantity == 1.

var item: ItemData
var quantity: int = 1


func _init(p_item: ItemData = null, p_quantity: int = 1) -> void:
	item = p_item
	quantity = p_quantity
