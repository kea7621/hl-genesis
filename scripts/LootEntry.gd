extends Resource
class_name LootEntry

## One line of a loot table: an item and the percent chance it's included
## when the table is rolled. Rolled independently of every other entry —
## see LootTable.roll().
##
## min_count/max_count control how many units drop when this entry
## succeeds — a random amount in that inclusive range (both default to 1,
## so every existing entry keeps behaving exactly as before unless you
## raise max_count). Only stackable items (see ItemData.is_stackable())
## actually use this — see roll_count() below.

@export var item: ItemData
@export_range(0.0, 100.0) var chance: float = 50.0
@export var min_count: int = 1
@export var max_count: int = 1


## How many units this entry drops on a successful roll. Non-stackable
## items (weapons, tools, armor) always return 1 regardless of
## min_count/max_count — those can't stack, so "3 of the same pistol"
## isn't a meaningful drop and this quietly clamps it rather than
## producing three separate pistol entries.
func roll_count() -> int:
	if item == null or not item.is_stackable():
		return 1
	var lo: int = max(min(min_count, max_count), 1)
	var hi: int = max(max(min_count, max_count), 1)
	return randi_range(lo, hi)
