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

const WEAPON_SLOTS := ["primary", "secondary", "melee"]  # armor excluded — not switchable/active

@export var capacity: int = 20
@export var starting_items: Array[ItemData] = []  # assign starting gear here, in order — auto-equips if equip_slot is set

var slots: Array[ItemData] = []
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
			slots[i] = item
	inventory_changed.emit()


## Equips whatever's in general slot `index` into its item.equip_slot,
## swapping with anything already there (the old item goes back into that
## same general slot — a straight swap, nothing is lost). Returns false if
## the item can't be equipped (equip_slot is NONE) or the index is invalid.
func equip_item(index: int) -> bool:
	if index < 0 or index >= slots.size() or slots[index] == null:
		return false

	var item: ItemData = slots[index]
	if item.equip_slot == ItemData.EquipSlot.NONE:
		return false

	var slot_name: String = _slot_name(item.equip_slot)
	var previous: ItemData = equipped.get(slot_name)

	slots[index] = previous  # swap — previous occupant (or null) goes back where the new item came from
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

	slots[free_index] = item
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


## Puts an item in the first empty general slot. Returns false if full.
## Used for loot/crafting output — never auto-equips, even if the item is
## equippable, so picking things up doesn't silently swap your gear.
func add_item(item: ItemData) -> bool:
	for i in slots.size():
		if slots[i] == null:
			slots[i] = item
			inventory_changed.emit()
			return true
	return false


func remove_item(index: int) -> void:
	if index < 0 or index >= slots.size():
		return
	slots[index] = null
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
