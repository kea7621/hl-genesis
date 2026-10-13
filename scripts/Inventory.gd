extends Node
class_name Inventory

## Two layers: a general-purpose slot array (the "backpack" — crafting
## materials, spare weapons, anything not currently worn/wielded), and
## four named equip slots (Primary/Secondary/Melee/Armor — the
## "paperdoll"). Equipping something moves it OUT of the general slots
## into one of those four; unequipping moves it back.
##
## Separately: only one of Primary/Secondary/Melee can be the ACTIVE
## weapon at a time (what Player.gd actually attacks with) even though all
## three can be equipped simultaneously — that's active_weapon_slot,
## switched via number keys in Player.gd, independent of what's equipped
## where. Armor has no "active" concept, it's passive.
##
## Stacking: each general slot holds an ItemStack (item + quantity) rather
## than a bare ItemData, so several units of a stackable item (crafting
## materials — see ItemData.is_stackable()) share one slot instead of
## eating one slot per unit. Weapons/tools/armor are never stackable, so a
## slot holding one of those always has quantity 1 — functionally
## identical to the old one-item-per-slot behavior. An empty slot is still
## just `null`.

const WEAPON_SLOTS := ["primary", "secondary", "melee"]  # armor excluded — not switchable/active

@export var capacity: int = 20
@export var starting_items: Array[ItemData] = []  # assign starting gear here, in order — auto-equips if equip_slot is set

var slots: Array[ItemStack] = []
var equipped: Dictionary = {"primary": null, "secondary": null, "melee": null, "armor": null}
var active_weapon_slot: String = ""
var is_ui_open: bool = false  # set by InventoryUI/CraftingUI/LootUI; Player checks this to block firing while browsing

signal inventory_changed
signal equip_slot_changed(slot_name: String, item: ItemData)  # drives equip-slot icon UI
signal active_weapon_changed(item: ItemData)  # drives Player's torso/muzzle swap


func _ready() -> void:
	slots.resize(capacity)
	for i in starting_items.size():
		if i >= capacity:
			break
		var item: ItemData = starting_items[i]
		if item == null:
			continue
		var slot_name: String = _slot_name(item.equip_slot)
		# Only auto-equip if that slot isn't already spoken for — two
		# starting items both set to the same equip_slot (e.g. two
		# Secondary-slot items) would otherwise silently overwrite each
		# other and lose one. The loser just lands in the backpack instead.
		if slot_name != "" and equipped.get(slot_name) == null:
			_equip_direct(item)
		else:
			slots[i] = ItemStack.new(item, 1)
	inventory_changed.emit()


## Equips whatever's in general slot `index` into its item.equip_slot,
## swapping with anything already there (the old item goes back into that
## same general slot — a straight swap, nothing is lost). Returns false if
## the item can't be equipped (equip_slot is NONE) or the index is invalid.
func equip_item(index: int) -> bool:
	if index < 0 or index >= slots.size() or slots[index] == null:
		return false

	var item: ItemData = slots[index].item
	if item.equip_slot == ItemData.EquipSlot.NONE:
		return false

	var slot_name: String = _slot_name(item.equip_slot)
	var previous: ItemData = equipped.get(slot_name)

	# Equippable items (weapons/armor) are never stackable, so this is
	# always a straight 1-for-1 swap — previous occupant (or null) goes
	# back where the new item came from, as its own single-quantity stack.
	slots[index] = ItemStack.new(previous, 1) if previous != null else null
	equipped[slot_name] = item
	equip_slot_changed.emit(slot_name, item)
	inventory_changed.emit()

	if slot_name in WEAPON_SLOTS:
		set_active_weapon(slot_name)  # equipping a weapon puts it straight into your hand

	return true


## Moves whatever's in the given equip slot ("primary"/"secondary"/
## "melee"/"armor") back into the first empty general slot. No-op if the
## equip slot is already empty or the backpack is full.
func unequip_slot(slot_name: String) -> bool:
	var item: ItemData = equipped.get(slot_name)
	if item == null:
		return false

	var free_index: int = -1
	for i in slots.size():
		if slots[i] == null:
			free_index = i
			break
	if free_index == -1:
		return false  # backpack full — leave it equipped rather than deleting it

	slots[free_index] = ItemStack.new(item, 1)
	equipped[slot_name] = null
	equip_slot_changed.emit(slot_name, null)
	inventory_changed.emit()

	if active_weapon_slot == slot_name:
		active_weapon_slot = ""
		active_weapon_changed.emit(null)

	return true


## Switches which equipped weapon is actively in-hand. No-op if that slot
## has nothing equipped. Armor is intentionally not a valid argument here.
func set_active_weapon(slot_name: String) -> bool:
	if slot_name not in WEAPON_SLOTS:
		return false
	var item: ItemData = equipped.get(slot_name)
	if item == null:
		return false
	active_weapon_slot = slot_name
	active_weapon_changed.emit(item)
	return true


func get_active_weapon() -> ItemData:
	if active_weapon_slot == "":
		return null
	return equipped.get(active_weapon_slot)


func get_armor() -> ItemData:
	return equipped.get("armor")


## Adds `quantity` units of `item` in one go and returns how many did NOT
## fit (0 = everything was added). Stackable items first top up any
## existing stacks of the same item that have room under max_stack, then
## spill into empty slots (each new stack holds up to max_stack). Anything
## non-stackable (weapons/tools/armor) takes one slot per unit. This is
## what lets a whole already-stacked pile (a loot container's "Resin x5", a
## dropped stack) go into the backpack at once instead of one unit at a
## time, and lets the caller keep whatever didn't fit. Never auto-equips,
## even if the item is equippable, so picking things up doesn't silently
## swap your gear.
func add_stack(item: ItemData, quantity: int) -> int:
	if item == null or quantity <= 0:
		return max(quantity, 0)

	var remaining: int = quantity

	if item.is_stackable():
		for stack in slots:
			if remaining <= 0:
				break
			if stack != null and stack.item == item and stack.quantity < item.max_stack:
				var room: int = item.max_stack - stack.quantity
				var moved: int = min(room, remaining)
				stack.quantity += moved
				remaining -= moved

	var per_slot: int = item.max_stack if item.is_stackable() else 1
	for i in slots.size():
		if remaining <= 0:
			break
		if slots[i] == null:
			var moved: int = min(per_slot, remaining)
			slots[i] = ItemStack.new(item, moved)
			remaining -= moved

	if remaining < quantity:
		inventory_changed.emit()
	return remaining


## Adds one unit of `item` (see add_stack() for the stacking rules).
## Returns false only if there was no room at all.
func add_item(item: ItemData) -> bool:
	return add_stack(item, 1) == 0


## Drag-and-drop behaviour for the backpack grid: moves the stack in
## `from_index` onto `to_index`.
##  - Empty target: the stack just moves there.
##  - Same stackable item: merges into the target up to max_stack; any
##    remainder stays in the source slot.
##  - Anything else (different item, or the target stack is already full):
##    the two stacks swap places, so nothing is ever lost.
## Returns false if the indexes are invalid or the source slot is empty.
func move_slot(from_index: int, to_index: int) -> bool:
	if from_index == to_index:
		return false
	if from_index < 0 or from_index >= slots.size() or to_index < 0 or to_index >= slots.size():
		return false
	var src: ItemStack = slots[from_index]
	if src == null:
		return false
	var dst: ItemStack = slots[to_index]

	if dst == null:
		slots[to_index] = src
		slots[from_index] = null
	elif src.item == dst.item and src.item.is_stackable() and dst.quantity < src.item.max_stack:
		var moved: int = min(src.item.max_stack - dst.quantity, src.quantity)
		dst.quantity += moved
		src.quantity -= moved
		if src.quantity <= 0:
			slots[from_index] = null
	else:
		slots[to_index] = src
		slots[from_index] = dst

	inventory_changed.emit()
	return true


## Removes up to `amount` units from the stack at `index` (clearing the
## slot if it empties) and returns how many were actually removed.
func remove_from_slot(index: int, amount: int) -> int:
	if index < 0 or index >= slots.size() or slots[index] == null or amount <= 0:
		return 0
	var removed: int = min(amount, slots[index].quantity)
	slots[index].quantity -= removed
	if slots[index].quantity <= 0:
		slots[index] = null
	inventory_changed.emit()
	return removed


## Removes one unit from the stack at `index`, clearing the slot entirely
## once its quantity reaches zero.
func remove_item(index: int) -> void:
	if index < 0 or index >= slots.size() or slots[index] == null:
		return
	slots[index].quantity -= 1
	if slots[index].quantity <= 0:
		slots[index] = null
	inventory_changed.emit()


## Total quantity of `item` held across every stack — the stacking-aware
## replacement for "count matching slots". Used by Crafting.gd.
func count_item(item: ItemData) -> int:
	if item == null:
		return 0
	var total := 0
	for stack in slots:
		if stack != null and stack.item == item:
			total += stack.quantity
	return total


## Removes up to `amount` units of `item`, spread across as many stacks as
## needed (in slot order). Used by Crafting.gd to consume ingredients.
func remove_item_amount(item: ItemData, amount: int) -> void:
	if item == null or amount <= 0:
		return
	var remaining := amount
	for i in slots.size():
		if remaining <= 0:
			break
		var stack: ItemStack = slots[i]
		if stack == null or stack.item != item:
			continue
		var take: int = min(remaining, stack.quantity)
		stack.quantity -= take
		remaining -= take
		if stack.quantity <= 0:
			slots[i] = null
	inventory_changed.emit()


func _slot_name(equip_slot: ItemData.EquipSlot) -> String:
	match equip_slot:
		ItemData.EquipSlot.PRIMARY:
			return "primary"
		ItemData.EquipSlot.SECONDARY:
			return "secondary"
		ItemData.EquipSlot.MELEE:
			return "melee"
		ItemData.EquipSlot.ARMOR:
			return "armor"
	return ""


## Used only during _ready() for starting_items — equips directly into a
## slot without going through the general array at all (so your starting
## loadout doesn't eat backpack space it never needed to occupy).
func _equip_direct(item: ItemData) -> void:
	var slot_name: String = _slot_name(item.equip_slot)
	if slot_name == "":
		return
	equipped[slot_name] = item
	if slot_name in WEAPON_SLOTS and active_weapon_slot == "":
		active_weapon_slot = slot_name
