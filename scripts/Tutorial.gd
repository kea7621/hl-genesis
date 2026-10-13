extends "res://scripts/Main.gd"

## The tutorial level. Reuses everything Main.gd already does (stamina
## banner, boss bar watching) and changes two things:
##  1. No timed loot respawn — the tutorial's containers are meant to hand
##     out exactly what each lesson needs, once.
##  2. Every enemy placed under the "RequiredEnemies" node is added to the
##     "tutorial_required" group, which is what keeps the LevelExit locked
##     until they're all dead. Drag more enemies into that node (or move
##     some out) to change what the player has to beat.

const REQUIRED_GROUP := "tutorial_required"


func _ready() -> void:
	super._ready()
	var required := get_node_or_null("RequiredEnemies")
	if required != null:
		for enemy in required.get_children():
			enemy.add_to_group(REQUIRED_GROUP)


func _on_loot_respawn_timeout() -> void:
	pass  # intentionally empty — see the note at the top of this file
