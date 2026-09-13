@tool
extends Area3D
class_name SurfFinish

## The finish: a wall across the channel with a gateway through it, plus the
## trigger filling that opening. Drag it to move the finish line; set the
## opening in the Inspector and the wall rebuilds around it.
##
## Origin is the centre of the gateway's base, sitting on the floor.

signal crossed

## Half the width of the gateway. Make it at least as wide as the channel:
## riders leave the last ramp still drifting sideways, so a narrow opening is
## missed by lines that look fine.
@export_range(10.0, 400.0, 1.0) var opening_half_width := 62.0:
	set(v):
		opening_half_width = v
		_rebuild()

@export_range(10.0, 400.0, 1.0) var opening_height := 95.0:
	set(v):
		opening_height = v
		_rebuild()

## How far the wall carries on past the gateway on each side.
@export_range(0.0, 400.0, 1.0) var wall_extra := 160.0:
	set(v):
		wall_extra = v
		_rebuild()

@export_range(10.0, 600.0, 1.0) var wall_height := 250.0:
	set(v):
		wall_height = v
		_rebuild()

## How far the wall continues below the floor, so it does not look to be
## floating when the pad beneath it is narrower than the wall.
@export_range(0.0, 300.0, 1.0) var skirt := 60.0:
	set(v):
		skirt = v
		_rebuild()

@export var color := Color(0.72, 0.66, 0.58):
	set(v):
		color = v
		_rebuild()


func _ready() -> void:
	_rebuild()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is SurfPlayer:
		crossed.emit()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child.owner == null:
			remove_child(child)
			child.queue_free()

	var thick := 8.0
	var half := opening_half_width
	var outer := half + wall_extra

	# Wall either side of the gateway, and the span above it.
	_slab(-outer, -half, -skirt, wall_height, thick)
	_slab(half, outer, -skirt, wall_height, thick)
	_slab(-half, half, opening_height, wall_height, thick)

	# Towers flanking the gateway, with battlement caps.
	for s: float in [-1.0, 1.0]:
		var x: float = s * (half + 14.0)
		_slab(x - 14.0, x + 14.0, -skirt, wall_height + 34.0, thick + 20.0)
		_slab(x - 19.0, x + 19.0, wall_height + 34.0, wall_height + 44.0, thick + 30.0)

	# The trigger fills exactly the opening, so finishing means going through it.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(half * 2.0, opening_height, 8.0)
	shape.shape = box
	shape.position = Vector3(0.0, opening_height * 0.5, 0.0)
	add_child(shape)


## One slab of wall. Solid, so the gateway is the only way past.
func _slab(x0: float, x1: float, y0: float, y1: float, thick: float) -> void:
	var body := StaticBody3D.new()
	body.position = Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, 0.0)
	var size := Vector3(absf(x1 - x0), absf(y1 - y0), thick)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	add_child(body)
