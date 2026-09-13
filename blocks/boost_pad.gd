@tool
extends Area3D
class_name SurfBoostPad

## A strip that shoves you along the way it is pointing. Rotate the node to aim
## it -- the push follows its own -Z, the same direction the editor gizmo's blue
## arrow points.
##
## Origin is the centre of the strip's top face.

@export var size := Vector3(14.0, 1.0, 24.0):
	set(v):
		size = v
		_rebuild()

## Speed added in m/s. For reference the ground run speed is 7 and a good surf
## line runs 25-40, so 12 is a noticeable kick rather than a teleport.
@export_range(1.0, 120.0, 0.5) var boost := 12.0

@export var color := Color(1.0, 0.72, 0.35):
	set(v):
		color = v
		_rebuild()


func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is SurfPlayer:
		# body_entered fires once per entry, so this cannot stack while resting
		# on the pad.
		(body as SurfPlayer).velocity += -global_basis.z.normalized() * boost


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
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.5
	mesh_inst.material_override = mat
	add_child(mesh_inst)

	# An arrow so you can see which way it pushes without selecting it.
	var arrow := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = size.x * 0.18
	cone.height = size.z * 0.25
	arrow.mesh = cone
	arrow.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	arrow.position = Vector3(0.0, 0.2, -size.z * 0.25)
	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(1, 1, 1)
	amat.emission_enabled = true
	amat.emission = Color(1, 1, 1)
	arrow.material_override = amat
	add_child(arrow)
