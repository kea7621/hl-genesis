@tool
extends EditorScript

## Batch-creates/updates LootTable .tres files from the table below —
## same workflow as GenerateItems.gd / GenerateRecipes.gd. Chance is a
## percent (0-100) rolled independently per item — see LootTable.roll()
## for exactly what that means.
##
## HOW TO USE:
##   1. Make sure the item(s) referenced already exist.
##   2. Add an entry to LOOT_TABLES (copy the example, edit it).
##   3. Open this file in Godot's Script tab. File > Run (Ctrl+Shift+X).
##   4. Drag the resulting .tres into a LootContainer's "Loot Table" field.

const LOOT_TABLES := [
	{
		"file": "TableLootBasic",  # -> resources/loot/TableLootBasic.tres
		"entries": [
			{"item": "res://resources/items/BrokenUSP.tres", "chance": 20.0},
			{"item": "res://resources/items/BrokenSMG.tres", "chance": 5.0},
			{"item": "res://resources/items/ScrapMetal.tres", "chance": 75.0},
		],
	},
	# Add more loot tables here — copy the entry above and edit it.
]


func _run() -> void:
	for spec in LOOT_TABLES:
		var table := LootTable.new()

		var entries: Array[LootEntry] = []
		for entry_spec in spec.get("entries", []):
			var entry := LootEntry.new()
			entry.item = load(entry_spec["item"]) as ItemData
			entry.chance = entry_spec.get("chance", 50.0)
			entries.append(entry)
		table.entries = entries

		var path := "res://resources/loot/%s.tres" % spec["file"]
		var result := ResourceSaver.save(table, path)
		if result == OK:
			print("Loot table saved: ", path)
		else:
			push_error("Failed to save %s (error %d)" % [path, result])

	print("Done — %d loot table(s) processed." % LOOT_TABLES.size())
