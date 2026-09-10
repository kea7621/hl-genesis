@tool
extends EditorScript

## Batch-creates/updates LootTable .tres files from the table below —
## same workflow as GenerateItems.gd / GenerateRecipes.gd. Chance is a
## percent (0-100) rolled independently per item — see LootTable.roll()
## for exactly what that means. Listing the same item more than once in
## one table's entries is the intended way to get "usually a little,
## sometimes a lot" — e.g. three Resin entries at descending chances
## simulates a variable-sized resin drop without needing a quantity
## field on LootEntry.
##
## HOW TO USE:
##   1. Make sure the item(s) referenced already exist.
##   2. Add an entry to LOOT_TABLES (copy the example, edit it).
##   3. Open this file in Godot's Script tab. File > Run (Ctrl+Shift+X).
##   4. Drag the resulting .tres into a LootContainer's "Loot Table" field.
##
## These mirror the hand-tuned tables already in resources/loot/ — re-run
## this to regenerate them from scratch if you want to retune the curve.
## Resin is the only crafting material in the game; the only other drop
## is the USP Match pistol as an early found weapon (it isn't craftable).

const LOOT_TABLES := [
	{
		"file": "TableLootBasic",
		"entries": [
			{"item": "res://resources/items/Resin.tres", "chance": 65.0},
			{"item": "res://resources/items/Resin.tres", "chance": 25.0},
			{"item": "res://resources/items/USPMatch.tres", "chance": 8.0},
		],
	},
	{
		"file": "TableLootScavenger",
		"entries": [
			{"item": "res://resources/items/Resin.tres", "chance": 70.0},
			{"item": "res://resources/items/Resin.tres", "chance": 30.0},
			{"item": "res://resources/items/USPMatch.tres", "chance": 10.0},
		],
	},
	{
		"file": "TableLootIndustrial",
		"entries": [
			{"item": "res://resources/items/Resin.tres", "chance": 80.0},
			{"item": "res://resources/items/Resin.tres", "chance": 45.0},
			{"item": "res://resources/items/Resin.tres", "chance": 15.0},
			{"item": "res://resources/items/USPMatch.tres", "chance": 15.0},
		],
	},
	{
		"file": "TableLootMilitary",
		"entries": [
			{"item": "res://resources/items/Resin.tres", "chance": 85.0},
			{"item": "res://resources/items/Resin.tres", "chance": 55.0},
			{"item": "res://resources/items/Resin.tres", "chance": 25.0},
			{"item": "res://resources/items/USPMatch.tres", "chance": 20.0},
		],
	},
	{
		"file": "TableLootArmory",
		"entries": [
			{"item": "res://resources/items/Resin.tres", "chance": 85.0},
			{"item": "res://resources/items/Resin.tres", "chance": 60.0},
			{"item": "res://resources/items/Resin.tres", "chance": 30.0},
			{"item": "res://resources/items/USPMatch.tres", "chance": 25.0},
		],
	},
	{
		"file": "TableLootHighTier",
		"entries": [
			{"item": "res://resources/items/Resin.tres", "chance": 90.0},
			{"item": "res://resources/items/Resin.tres", "chance": 65.0},
			{"item": "res://resources/items/Resin.tres", "chance": 40.0},
			{"item": "res://resources/items/Resin.tres", "chance": 15.0},
		],
	},
	{
		"file": "TableLootEndGame",
		"entries": [
			{"item": "res://resources/items/Resin.tres", "chance": 95.0},
			{"item": "res://resources/items/Resin.tres", "chance": 75.0},
			{"item": "res://resources/items/Resin.tres", "chance": 50.0},
			{"item": "res://resources/items/Resin.tres", "chance": 25.0},
		],
	},
	{
		"file": "TableLootBoss",
		"entries": [
			{"item": "res://resources/items/Resin.tres", "chance": 100.0},
			{"item": "res://resources/items/Resin.tres", "chance": 90.0},
			{"item": "res://resources/items/Resin.tres", "chance": 70.0},
			{"item": "res://resources/items/Resin.tres", "chance": 45.0},
			{"item": "res://resources/items/Resin.tres", "chance": 20.0},
		],
	},
	# Add more loot tables here — copy an entry above and edit it.
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
