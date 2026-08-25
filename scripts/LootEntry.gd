extends Resource
class_name LootEntry

## One line of a loot table: an item and the percent chance it's included
## when the table is rolled. Rolled independently of every other entry —
## see LootTable.roll().

@export var item: ItemData
@export_range(0.0, 100.0) var chance: float = 50.0
