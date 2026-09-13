@tool
extends StaticBody3D
class_name SurfPlatform

## A flat pad. Drag it anywhere; set its size in the Inspector.
## Origin is the centre of the top surface, which is the bit you care about
## lining up against a ramp.

@export var size := Vector3(42.0, 4.0, 45.0):
	set(v):
		size = v
		_rebuild()

@export var color := Color(0.72, 0.66, 0.58):
	set(v):
		color = v
		_rebuild()


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child.owner == null:
			remove_child(child)
			child.queue_free()

	var offset := Vector3(0.0, -size.y * 0.5, 0.0)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = offset
	add_child(shape)

	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_inst.mesh = mesh
	mesh_inst.position = offset
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mesh_inst.material_override = mat
	add_child(mesh_inst)
