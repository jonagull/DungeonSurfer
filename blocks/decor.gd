@tool
extends Node3D
class_name SurfDecor

## Non-colliding scenery, generated from a seed so it costs one node in the
## scene file rather than a hundred. Purely so you can perceive speed -- surf
## feels flat without something streaming past you.

@export var count := 40:
	set(v):
		count = v
		_rebuild()

## Scenery is scattered in a band this far out to either side, so it never
## intrudes on the channel itself.
@export var inner_x := 80.0:
	set(v):
		inner_x = v
		_rebuild()

@export var outer_x := 200.0:
	set(v):
		outer_x = v
		_rebuild()

@export var extent := Vector3(0.0, 120.0, 400.0):
	set(v):
		extent = v
		_rebuild()

@export var rng_seed := 7919:
	set(v):
		rng_seed = v
		_rebuild()

@export var color := Color(0.26, 0.24, 0.40):
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

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for i in count:
		var inst := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		var s := rng.randf_range(6.0, 22.0)
		mesh.size = Vector3(s, rng.randf_range(20.0, 80.0), s)
		inst.mesh = mesh
		inst.material_override = mat
		inst.position = Vector3(
			(1.0 if rng.randf() > 0.5 else -1.0) * rng.randf_range(inner_x, outer_x),
			rng.randf_range(-extent.y, extent.y * 0.4),
			rng.randf_range(0.0, extent.z)
		)
		inst.rotation.y = rng.randf_range(0.0, TAU)
		add_child(inst)
