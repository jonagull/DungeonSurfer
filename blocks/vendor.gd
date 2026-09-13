@tool
extends StaticBody3D
class_name Vendor

## A character you can stand next to and talk to.
##
## The body is authored in vendor.tscn as ordinary mesh nodes -- swap them for a
## real model whenever you like. This script only handles noticing the player,
## showing the prompt, and stepping through the lines.

@export var vendor_name := "Vendor"

## One entry per press of the interact key. Edit these in the Inspector.
@export_multiline var lines: PackedStringArray = []

@export var interact_range := 7.0
## Turns to face the player when they are close.
@export var face_player := true

var _player: SurfPlayer = null
var _in_range := false
var _line := -1


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group("vendors")


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as SurfPlayer
		if _player == null:
			return

	var to_player := _player.global_position - global_position
	var near := to_player.length() <= interact_range
	if near != _in_range:
		_in_range = near
		if not near:
			_end()
	if not near:
		return

	if face_player:
		var flat := Vector3(to_player.x, 0.0, to_player.z)
		if flat.length_squared() > 0.01:
			rotation.y = rotate_toward(rotation.y, atan2(flat.x, flat.z), 4.0 * delta)

	var box := _dialogue()
	if box == null:
		return
	if _line < 0:
		box.show_prompt("%s  --  press E" % vendor_name)
	if Input.is_action_just_pressed("interact"):
		_advance()


func _advance() -> void:
	_line += 1
	var box := _dialogue()
	if box == null:
		return
	if _line >= lines.size():
		_end()
		return
	box.show_line(vendor_name, lines[_line])


func _end() -> void:
	_line = -1
	var box := _dialogue()
	if box != null:
		box.clear()


func _dialogue() -> Node:
	return get_tree().get_first_node_in_group("dialogue")
