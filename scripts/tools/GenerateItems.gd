@tool
extends EditorScript

## Batch-creates/updates ItemData .tres files from the table below.
##
## HOW TO USE:
##   1. Add an entry to ITEMS (copy an existing one, change the values).
##   2. Open this file in Godot's Script tab.
##   3. File > Run (or Ctrl+Shift+X).
##   4. Check the Output panel — it prints every file it wrote.
##
## Re-running is safe and idempotent: existing files with matching names
## get overwritten with the new values, so this doubles as a bulk-retune
## tool (e.g. change one damage number here, 
## Only the fields relevant to `type` actually matter at runtime — the
## rest are harmless to leave at their defaults.re-run, every listed item
## updates at once instead of hand-editing each .tres).
##

const ITEMS := [
	{
		"file": "PipeWrench",  # -> resources/items/PipeWrench.tres
		"name": "Pipe Wrench",
		"type": ItemData.ItemType.MELEE,
		"equip_slot": ItemData.EquipSlot.MELEE,
		"damage": 16.0,
		"melee_range": 44.0,
		"melee_cooldown": 0.45,
		"muzzle_offset": Vector2(26, 0),
	},
	{
		"file": "BrokenSMG",  # -> resources/items/BrokenSMG.tres
		"name": "Broken MP7",
		"type": ItemData.ItemType.CRAFTING,
	},
	{
		"file": "BrokenUSP",  # -> resources/items/BrokenUSP.tres
		"name": "Broken USP",
		"type": ItemData.ItemType.CRAFTING,
	},
	{
		"file": "SMGParts",  # -> resources/items/SMGParts.tres
		"name": "SMG Parts",
		"type": ItemData.ItemType.CRAFTING,
	},
	{
		"file": "ShotgunParts",  # -> resources/items/ShotgunParts.tres
		"name": "Shotgun Parts",
		"type": ItemData.ItemType.CRAFTING,
	},
	{
		"file": "PistolParts",  # -> resources/items/PistolParts.tres
		"name": "Pistol Parts",
		"type": ItemData.ItemType.CRAFTING,
	},
	{
		"file": "BrokenShotgun",  # -> resources/items/BrokenShotgun.tres
		"name": "Broken M870",
		"type": ItemData.ItemType.CRAFTING,
	},
	{
		"file": "Screws",  # -> resources/items/Screws.tres
		"name": "Screws",
		"type": ItemData.ItemType.CRAFTING,
	},
	{
		"file": "Springs",  # -> resources/items/Springs.tres
		"name": "Springs",
		"type": ItemData.ItemType.CRAFTING,
	},
	{
		"file": "Plastic",  # -> resources/items/Plastic.tres
		"name": "Plastic",
		"type": ItemData.ItemType.CRAFTING,
	},
	# Add more items here — copy the entry above and edit it.
	# equip_slot: ItemData.EquipSlot.{PRIMARY,SECONDARY,MELEE,ARMOR,NONE}
	#   — leave unset (defaults to NONE) for anything that can't be equipped.
	# Ranged example fields: fire_mode, projectile_scene, fire_rate, projectile_speed
	# Tool example fields: use_range, use_cooldown
	# Armor example fields: armor_value
	# Crafting materials: just "file", "name", "type" — nothing else needed.
]


func _run() -> void:
	for spec in ITEMS:
		var item := ItemData.new()
		item.item_name = spec.get("name", "New Item")
		item.item_type = spec.get("type", ItemData.ItemType.CRAFTING)
		item.equip_slot = spec.get("equip_slot", ItemData.EquipSlot.NONE)
		item.damage = spec.get("damage", 0.0)
		item.muzzle_offset = spec.get("muzzle_offset", Vector2(20, 0))
		item.torso_texture = spec.get("torso_texture", null)
		item.icon = spec.get("icon", null)

		# Ranged
		item.fire_mode = spec.get("fire_mode", ItemData.FireMode.SEMI_AUTO)
		item.projectile_scene = spec.get("projectile_scene", null)
		item.fire_rate = spec.get("fire_rate", 0.25)
		item.projectile_speed = spec.get("projectile_speed", 700.0)

		# Melee
		item.melee_range = spec.get("melee_range", 40.0)
		item.melee_cooldown = spec.get("melee_cooldown", 0.4)

		# Tool
		item.use_range = spec.get("use_range", 60.0)
		item.use_cooldown = spec.get("use_cooldown", 0.5)

		# Armor
		item.armor_value = spec.get("armor_value", 0.0)

		var path := "res://resources/items/%s.tres" % spec["file"]
		var result := ResourceSaver.save(item, path)
		if result == OK:
			print("Item saved: ", path)
		else:
			push_error("Failed to save %s (error %d)" % [path, result])

	print("Done — %d item(s) processed." % ITEMS.size())
