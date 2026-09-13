@tool
extends Area3D
class_name Portal

## A doorway to a level. Drop it in, drag a level scene into `target_level`,
## type a name. Walk into it to travel.
##
## Everything visible lives in portal.tscn as ordinary nodes -- the ring, the
## glow, the sign. This script only sets the sign's text and handles the
## trigger, so you can restyle the portal without touching code.

## Leave empty to mark the portal as not built yet. It will say so rather than
## silently doing nothing, which is what an unwired portal otherwise looks like.
@export var target_level: PackedScene:
	set(value):
		target_level = value
		_refresh()

@export var label := "Portal":
	set(value):
		label = value
		_refresh()

@export var tint := Color(0.45, 0.72, 1.0):
	set(value):
		tint = value
		_refresh()

var _player_has_left := false


func _ready() -> void:
	_refresh()


func _process(delta: float) -> void:
	var ring := get_node_or_null("Ring")
	if ring != null:
		(ring as Node3D).rotation.z += delta * 0.6


## Overlap is polled rather than driven by body_entered.
##
## The event only fires on the frame you cross the boundary. Pair that with any
## kind of arming delay and a player who walks in during the delay is rejected
## once and then never re-tested, because they never "enter" again -- the portal
## just quietly stops working while they stand in it. Polling cannot miss.
##
## Arming instead requires the portal to have seen the player *outside* it at
## least once, so arriving on top of a portal cannot bounce you straight back.
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var touching := false
	for body in get_overlapping_bodies():
		if body is SurfPlayer:
			touching = true
			break

	if not touching:
		_player_has_left = true
		return
	if not _player_has_left or target_level == null:
		return

	var course := get_tree().get_first_node_in_group("course") as SurfCourse
	if course == null:
		push_error("Portal found no Course in the scene")
		return
	_player_has_left = false
	course.load_scene(target_level)


func _refresh() -> void:
	if not is_inside_tree():
		return
	var sign_node := get_node_or_null("Sign") as Label3D
	if sign_node != null:
		sign_node.text = label if target_level != null else "%s\n(not built yet)" % label
		sign_node.modulate = tint if target_level != null else Color(0.6, 0.6, 0.6)
	var glow := get_node_or_null("Glow") as MeshInstance3D
	if glow != null and glow.material_override is StandardMaterial3D:
		var mat := glow.material_override as StandardMaterial3D
		mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.55)
		mat.emission = tint
	var light := get_node_or_null("Light") as OmniLight3D
	if light != null:
		light.light_color = tint

