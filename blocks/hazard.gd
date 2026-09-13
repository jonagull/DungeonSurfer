@tool
extends Area3D
class_name SurfHazard

## A volume that sends you back to your last checkpoint. Use it as a floor under
## a section so a miss costs a second instead of a long silent fall.
##
## The player already respawns after `fall_timeout` seconds of touching nothing,
## so this is for making a specific miss instant and obvious rather than for
## preventing softlocks.
##
## Origin is the centre of the volume.

@export var size := Vector3(400.0, 10.0, 400.0):
	set(v):
		size = v
		_rebuild()

## Off by default: a visible kill plane is usually noise once a level works.
@export var show_volume := false:
	set(v):
		show_volume = v
		_rebuild()

@export var color := Color(0.9, 0.3, 0.35, 0.25):
	set(v):
		color = v
		_rebuild()


func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is SurfPlayer:
		# Let the game mode decide whether that is a respawn or the end.
		(body as SurfPlayer).perish()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child.owner == null:
			remove_child(child)
			child.queue_free()

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)

	if not show_volume:
		return
	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_inst.material_override = mat
	add_child(mesh_inst)
