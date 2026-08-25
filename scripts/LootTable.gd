extends Resource
class_name LootTable

## A reusable "what's in this container" definition. Attach the same
## LootTable to multiple LootContainers if you want several tables/crates
## to share drop odds.

@export var entries: Array[LootEntry] = []


## Rolls each entry independently against its own chance — NOT a single
## weighted pick from the list. A table with a 20% gun and a 50% junk
## entry can produce: nothing, just the gun, just the junk, or both.
func roll() -> Array[ItemData]:
	var result: Array[ItemData] = []
	for entry in entries:
		if entry.item == null:
			continue
		if randf() * 100.0 <= entry.chance:
			result.append(entry.item)
	return result
