extends Node

## Set this up ONCE per level (one instance, anywhere in the scene).
## Point outdoor_container_path at whatever CanvasItem holds your
## outdoor-only visuals — a Node2D wrapping your outdoor props/ground, or
## directly a TileMapLayer if you're using separate layers for
## outdoor/indoor tiles (Godot 4.3+ TileMapLayer has its own `modulate`
## and `material`, so you can point straight at it with no wrapper node).
##
## Any number of IndoorZone triggers anywhere in the level (one per
## building/room) talk to this automatically via the "world_dimmer" group
## — you never wire a NodePath per zone. Ref-counts overlapping zones so
## walking from one room into an adjacent one (or overlapping doorway
## triggers) doesn't flicker back to full brightness in between.

@export var outdoor_container_path: NodePath
@export var fade_duration: float = 0.5
@export_range(0.0, 1.0) var max_gray_amount: float = 0.85  # 1.0 = fully greyscale
@export_range(0.0, 1.0) var max_dim_amount: float = 0.35   # extra darkening on top of the desaturation

const FOG_SHADER := preload("res://shaders/fog_of_war.gdshader")

var outdoor_container: CanvasItem
var _shader_material: ShaderMaterial
var _indoor_zone_count: int = 0
var _current_gray: float = 0.0
var _current_dim: float = 0.0
var _tween: Tween


func _ready() -> void:
	add_to_group("world_dimmer")

	outdoor_container = get_node(outdoor_container_path)
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = FOG_SHADER
	outdoor_container.material = _shader_material


## Called by IndoorZone.gd via group broadcast — don't call directly unless
## you're building a non-Area2D trigger of your own.
func enter_indoor() -> void:
	_indoor_zone_count += 1
	_update_fade()


func exit_indoor() -> void:
	_indoor_zone_count = max(_indoor_zone_count - 1, 0)
	_update_fade()


func _update_fade() -> void:
	var indoors: bool = _indoor_zone_count > 0
	var target_gray: float = max_gray_amount if indoors else 0.0
	var target_dim: float = max_dim_amount if indoors else 0.0

	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_method(_set_gray, _current_gray, target_gray, fade_duration)
	_tween.tween_method(_set_dim, _current_dim, target_dim, fade_duration)


func _set_gray(value: float) -> void:
	_current_gray = value
	_shader_material.set_shader_parameter("gray_amount", value)


func _set_dim(value: float) -> void:
	_current_dim = value
	_shader_material.set_shader_parameter("dim_amount", value)
