@tool
extends Area3D
class_name SurfBouncePad

## A pad that throws you upward when you touch it, keeping the speed you
## arrived with. Use it to link a low exit to a high entry, or to give a dead
## end a way out.
##
## Origin is the centre of the pad's top face.

@export var size := Vector3(16.0, 1.5, 16.0):
	set(v):
		size = v
		_rebuild()

## Upward speed in m/s. The player's jump is 7.6, so 16 is roughly a quadruple
## jump. Set against gravity 20: height is roughly launch^2 / 40.
@export_range(1.0, 80.0, 0.5) var launch := 16.0

## Only ever raises your vertical speed, so hitting it while already rising
## cannot slow you down.
@export var color := Color(0.45, 0.95, 0.7):
	set(v):
		color = v
		_rebuild()


func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is SurfPlayer:
		var player := body as SurfPlayer
		player.velocity.y = maxf(player.velocity.y, launch)


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
	mat.emission_energy_multiplier = 0.6
	mesh_inst.material_override = mat
	add_child(mesh_inst)
