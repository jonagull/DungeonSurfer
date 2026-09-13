@tool
extends StaticBody3D
class_name SurfRamp

## One surf ramp you can place, drag and rotate like any other node.
##
## The node's own transform is entirely yours -- move it, yaw it, pitch it. The
## ramp's tilt lives on its generated child instead, so dragging the node can
## never put the face at an angle that stops working.
##
## The mesh and collider are rebuilt from the properties below and are given no
## `owner`, so they are not written into the .tscn. A ramp saves as a handful of
## numbers, and changing one updates the viewport immediately.
##
## The origin sits on the ramp's low, long edge -- the lip you fall off -- which
## is the edge you actually position when laying out a channel.

## Which side of the channel this wall sits on. Plain ints rather than a real
## enum: GDScript 4 cannot compile an enum-typed @export that also has a setter.
const LEFT_WALL := 0   ## Wall on the left of the channel; surface faces right (+X).
const RIGHT_WALL := 1  ## Wall on the right; surface faces left (-X).

## Must stay steeper than the player's floor_max_angle (45) or the engine treats
## the face as standable ground and you walk up it instead of surfing.
@export_range(30.0, 80.0, 0.5) var angle := 50.0:
	set(v):
		angle = v
		_rebuild()

## Length of the face up the slope. How much room there is to recover.
@export_range(5.0, 300.0, 1.0) var width := 45.0:
	set(v):
		width = v
		_rebuild()

## How far the ramp runs along its own +Z.
@export_range(5.0, 800.0, 1.0) var length := 55.0:
	set(v):
		length = v
		_rebuild()

@export_enum("Left wall", "Right wall") var side: int = LEFT_WALL:
	set(v):
		side = v
		_rebuild()

@export_range(1.0, 40.0, 0.5) var thickness := 6.0:
	set(v):
		thickness = v
		_rebuild()

@export var material_override_color := Color(0.42, 0.38, 0.62):
	set(v):
		material_override_color = v
		_rebuild()


func _ready() -> void:
	_rebuild()


## Unit normal of the surfable face, in local space.
func face_normal() -> Vector3:
	var a := deg_to_rad(angle)
	return Vector3(_face_sign() * sin(a), cos(a), 0.0)


## Unit vector pointing up the slope, in local space.
func up_slope() -> Vector3:
	var a := deg_to_rad(angle)
	return Vector3(-_face_sign() * cos(a), sin(a), 0.0)


func _face_sign() -> float:
	return 1.0 if side == LEFT_WALL else -1.0


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		# Only ever clear what we generated; anything the user parented here
		# belongs to the scene and has an owner.
		if child.owner == null:
			remove_child(child)
			child.queue_free()

	var a := deg_to_rad(angle)
	var surface_center := up_slope() * (width * 0.5) + Vector3(0.0, 0.0, length * 0.5)
	# The slab sits behind the face, so the face itself is what you ride.
	var centre := surface_center - face_normal() * (thickness * 0.5)
	var basis := Basis(Vector3.BACK, -_face_sign() * a)
	var xform := Transform3D(basis, centre)
	var size := Vector3(width, thickness, length)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.transform = xform
	add_child(shape)

	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_inst.mesh = mesh
	mesh_inst.transform = xform
	var mat := StandardMaterial3D.new()
	mat.albedo_color = material_override_color
	mat.roughness = 0.85
	mesh_inst.material_override = mat
	add_child(mesh_inst)
