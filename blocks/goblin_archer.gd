@tool
extends StaticBody3D
class_name GoblinArcher

## A goblin archer. Drop it anywhere in a level; it finds the player itself.
##
## It leads its shots, but only partly (see `lead`). A goblin that aimed
## perfectly would be unavoidable at 25 m/s, and one that aimed straight at you
## would never land a shot at all -- both are equally boring. Partial leading
## means arrows arrive near you and you weave.

const ARROW := preload("res://blocks/arrow.tscn")

## Starts shooting once you are this close.
@export var fire_range := 140.0
@export var fire_interval := 1.7
@export var arrow_speed := 48.0
## 0 aims where you are, 1 aims where you will be. Halfway is the sweet spot:
## threatening, still dodgeable.
@export_range(0.0, 1.0, 0.05) var lead := 0.55
## How fast it swings round to face you, radians per second.
@export var turn_speed := 5.0
@export var skin := Color(0.44, 0.62, 0.30)
@export var cloth := Color(0.55, 0.29, 0.22)
## Coins thrown out on death.
@export var coin_drop := 5

var _player: SurfPlayer = null
var _cooldown := 0.0
var _dying := false


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		return
	# Fireballs find their targets through this group.
	add_to_group("enemies")
	# Stagger the volley so a row of goblins does not fire in lockstep.
	_cooldown = randf() * fire_interval


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _dying:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as SurfPlayer
		if _player == null:
			return

	var to_player := _player.global_position - global_position
	if to_player.length() > fire_range:
		return

	_face(to_player, delta)
	_cooldown -= delta
	if _cooldown <= 0.0:
		_cooldown = fire_interval
		_shoot()


func _face(to_player: Vector3, delta: float) -> void:
	var flat := Vector3(to_player.x, 0.0, to_player.z)
	if flat.length_squared() < 0.01:
		return
	var want := atan2(flat.x, flat.z)
	rotation.y = rotate_toward(rotation.y, want, turn_speed * delta)


func _shoot() -> void:
	var muzzle := global_position + Vector3(0.0, 1.3, 0.0)
	var target := _player.global_position + Vector3(0.0, 0.9, 0.0)

	# Where the player will be when the arrow arrives, blended with where they
	# are now by `lead`.
	var flight := muzzle.distance_to(target) / arrow_speed
	target += _player.velocity * flight * lead

	var arrow: Area3D = ARROW.instantiate()
	arrow.speed = arrow_speed
	_spawn(arrow)
	arrow.global_position = muzzle
	arrow.look_at(target, Vector3.UP)


func _spawn(node: Node) -> void:
	_spawn_host().add_child(node)


## Projectiles and coins are parented to the scene, never to the shooter -- a
## goblin that dies mid-flight would otherwise take its arrows and its loot
## with it.
func _spawn_host() -> Node:
	var host := get_tree().current_scene
	return host if host != null else get_tree().root


## Killed by a fireball.
func die() -> void:
	if _dying:
		return
	_dying = true
	var player := get_tree().get_first_node_in_group("player") as SurfPlayer
	# Worth more the faster you were moving when you killed it.
	var worth := player.get_multiplier() if player != null else 1
	Coin.burst(_spawn_host(), global_position + Vector3(0, 1.1, 0), coin_drop, worth)
	if player != null:
		player.add_kill()
	# Topple over, then vanish. Cheap, but it reads as a kill at a glance.
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation:x", deg_to_rad(-80.0), 0.35)
	tween.tween_property(self, "scale", Vector3.ONE * 0.1, 0.4).set_delay(0.15)
	tween.chain().tween_callback(queue_free)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child.owner == null:
			remove_child(child)
			child.queue_free()

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.6
	shape.shape = capsule
	shape.position = Vector3(0.0, 0.8, 0.0)
	add_child(shape)

	_part(_capsule(0.42, 1.0), Vector3(0, 0.62, 0), cloth)          # body
	_part(_sphere(), Vector3(0, 1.32, 0), skin, 0.52)               # head
	for side: float in [-1.0, 1.0]:                                 # ears
		_part(_cone(0.14, 0.42), Vector3(side * 0.26, 1.38, 0), skin, 0.0,
			Vector3(0, 0, side * deg_to_rad(70.0)))
	_part(_capsule(0.11, 0.5), Vector3(-0.34, 0.95, -0.12), skin)   # bow arm
	_part(_capsule(0.11, 0.45), Vector3(0.30, 0.92, 0.05), skin)    # draw arm
	# Bow, held out front. -Z is the way it faces, so this is what you see
	# coming.
	_part(_torus(0.42, 0.05), Vector3(-0.40, 1.05, -0.30), Color(0.36, 0.25, 0.16),
		0.0, Vector3(deg_to_rad(90.0), 0, 0))


func _part(mesh: Mesh, pos: Vector3, color: Color, scale_to: float = 0.0,
		rot: Vector3 = Vector3.ZERO) -> void:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	inst.rotation = rot
	if scale_to > 0.0:
		inst.scale = Vector3.ONE * scale_to
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	inst.material_override = mat
	add_child(inst)


func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 10
	return m


func _cone(radius: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 8
	return m


func _sphere() -> SphereMesh:
	return SphereMesh.new()


func _torus(inner: float, tube: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = inner + tube
	return m
