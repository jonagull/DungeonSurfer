extends Area3D
class_name Fireball

## The player's fireball. One hit kills a goblin. Flies until it hits something.
##
## Two separate hit sizes, and the split matters:
##
## A single generous sphere seems right -- you are usually firing while pinned
## to a tilted wall at 25 m/s, and a pinpoint projectile under those conditions
## is a coin flip. But a fat sphere also collides with *terrain*, and the wall
## you are surfing is roughly an arm's length away, so the fireball detonated
## the moment it spawned. Shooting while surfing simply did not work; the only
## place it functioned was standing on a flat pad next to a goblin.
##
## So: a small shape for terrain, and a generous distance check for enemies.
## Forgiving where it should be, tight where it has to be. The distance check
## also cannot tunnel, which a 160 m/s projectile otherwise would.

@export var speed := 160.0
## Effectively unlimited -- it just cannot live forever if it never hits a thing.
@export var max_range := 3000.0
## Small, so it does not catch the ramp you are riding.
@export var terrain_radius := 0.5
## Generous, because aiming at speed is hard enough already.
@export var enemy_radius := 2.8
## Terrain is ignored until the fireball has cleared this much, so the surface
## the player is standing on or surfing against cannot swallow it at birth.
## Short enough that a genuine wall a few metres ahead still stops it.
@export var arm_distance := 2.5

var _travelled := 0.0


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = terrain_radius
	shape.shape = sphere
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var step := speed * delta
	global_position += -global_basis.z * step
	_travelled += step

	if _check_enemies():
		return
	if _travelled > max_range:
		queue_free()


## Kill the first enemy within reach. Distance rather than overlap, so a fast
## projectile cannot skip past a goblin between two physics ticks.
func _check_enemies() -> bool:
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Node3D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position + Vector3(0, 0.9, 0)) < enemy_radius:
			if enemy.has_method("die"):
				enemy.die()
			queue_free()
			return true
	return false


func _on_body_entered(body: Node3D) -> void:
	# Never detonate on the wizard who threw it.
	if body is SurfPlayer:
		return
	if body is GoblinArcher:
		(body as GoblinArcher).die()
		queue_free()
		return
	# Terrain. Ignore it until we are clear of whatever we were standing on.
	if _travelled < arm_distance:
		return
	queue_free()
