extends Resource
class_name LootTable

## A reusable "what's in this container" definition. Attach the same
## LootTable to multiple LootContainers if you want several tables/crates
## to share drop odds.

@export var entries: Array[LootEntry] = []


## Rolls each entry independently against its own chance — NOT a single
## weighted pick from the list. A table with a 20% gun and a 50% junk
## entry can produce: nothing, just the gun, just the junk, or both. A
## successful stackable-item entry can also produce more than one unit —
## see LootEntry.roll_count() — represented here as that many separate
## copies of the same ItemData in the result (LootContainer.contents stays
## a flat Array[ItemData] either way, nothing downstream needs to know the
## difference between "5 separate 1-count rolls" and "1 roll of 5").
func roll() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for entry in entries:
		if entry.item == null:
			continue
		if randf() * 100.0 <= entry.chance:
			for i in entry.roll_count():
				result.append(entry.item)
	return result
