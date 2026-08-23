extends Node
class_name Inventory

## A fixed-capacity slot array, survival-game style — slots can be empty
## (null). One slot is "equipped" as primary at a time. This is the data
## layer only; InventoryUI reads/writes it, and a future Crafting object
## can call add_item()/remove_item() the same way pickups will.

@export var capacity: int = 20
@export var starting_items: Array[ItemData] = []  # assign Crowbar/USP Match here, in order

var slots: Array[ItemData] = []
var equipped_index: int = -1
var is_ui_open: bool = false  # set by InventoryUI; Player checks this to block firing while browsing

signal inventory_changed
signal equipped_changed(item: ItemData)


func _ready() -> void:
	slots.resize(capacity)
	for i in starting_items.size():
		if i < capacity:
			slots[i] = starting_items[i]
	inventory_changed.emit()

	if get_equipped() == null:
		for i in slots.size():
			if slots[i] != null:
				equip(i)
				break


## Puts an item in the first empty slot. Returns false if the inventory is full.
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
	if equipped_index == index:
		equipped_index = -1
		equipped_changed.emit(null)
	inventory_changed.emit()


func equip(index: int) -> void:
	if index < 0 or index >= slots.size() or slots[index] == null:
		return
	var item: ItemData = slots[index]
	if item.item_type == ItemData.ItemType.CRAFTING:
		return  # crafting materials can't be wielded in the primary slot
	equipped_index = index
	equipped_changed.emit(get_equipped())


func get_equipped() -> ItemData:
	if equipped_index < 0 or equipped_index >= slots.size():
		return null
	return slots[equipped_index]
