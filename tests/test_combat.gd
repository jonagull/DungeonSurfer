extends Node
# Checks the combat loop end to end: goblins shoot, arrows cost speed, fireballs
# kill goblins. Each of these fails silently if it fails at all -- an archer
# that never fires looks exactly like one that is out of range.

var _main: Node
var _player: SurfPlayer
var _failures: Array[String] = []


func _ready() -> void:
	# Coin scatter and goblin fire timing both use randf(). Without a fixed seed
	# the pile lands somewhere different every run and this test passes or fails
	# on a coin toss.
	seed(20260912)
	_main = load("res://main.tscn").instantiate()
	add_child(_main)
	_player = _main.get_node("Player")
	var course: SurfCourse = _main.get_node("Course")
	course.build_map(course.index_of("Castle Approach"))
	await get_tree().physics_frame

	await _check_level_has_goblins()
	await _check_goblin_shoots()
	await _check_arrow_drains_speed()
	await _check_fireball_kills()
	await _check_fireball_aim()
	await _check_coins_drop_and_collect()
	await _check_firing_while_surfing()
	await _check_long_range_kill()

	print("")
	if _failures.is_empty():
		print("PASS")
	else:
		for f in _failures:
			print("FAIL: " + f)
	get_tree().quit()


func _goblins() -> Array:
	var found: Array = []
	for node in _main.find_children("*", "GoblinArcher", true, false):
		found.append(node)
	return found


func _check_level_has_goblins() -> void:
	var n := _goblins().size()
	print("  level 1 contains %d goblin archers" % n)
	if n == 0:
		_failures.append("no goblins in level 1")


## Park the player in range and wait for an arrow to appear in the scene.
func _check_goblin_shoots() -> void:
	var goblins := _goblins()
	if goblins.is_empty():
		return
	var goblin: Node3D = goblins[0]
	_player.global_position = goblin.global_position + Vector3(0, 2, 40)
	_player.velocity = Vector3.ZERO
	var seen := 0
	for tick in 400:
		await get_tree().physics_frame
		seen = get_tree().get_nodes_in_group("_none").size()
		seen = _count_arrows()
		if seen > 0:
			break
	print("  goblin fired: %s (%d arrow(s) in flight)" % [str(seen > 0), seen])
	if seen == 0:
		_failures.append("goblin in range never fired")


func _count_arrows() -> int:
	var scene := get_tree().current_scene
	if scene == null:
		return 0
	return scene.find_children("*", "GoblinArrow", true, false).size()


## Fire an arrow straight at a stationary player and check the speed loss.
func _check_arrow_drains_speed() -> void:
	_player.global_position = Vector3(8000, 400, 8000)
	_player.velocity = Vector3(0, 0, 30.0)
	await get_tree().physics_frame
	var before := _player.get_horizontal_speed()

	var arrow: Area3D = load("res://blocks/arrow.tscn").instantiate()
	get_tree().current_scene.add_child(arrow)
	arrow.global_position = _player.global_position + Vector3(0, 0.9, 6.0)
	arrow.look_at(_player.global_position + Vector3(0, 0.9, 0), Vector3.UP)

	for tick in 60:
		await get_tree().physics_frame
		if _player.get_hit_fx() > 0.0:
			break
	var after := _player.get_horizontal_speed()
	var lost := before - after
	print("  arrow hit: %.1f -> %.1f m/s (lost %.1f)" % [before, after, lost])
	if lost < 1.0:
		_failures.append("arrow did not drain speed")


## Aim a fireball at a goblin and check it dies.
func _check_fireball_kills() -> void:
	var goblins := _goblins()
	if goblins.is_empty():
		return
	var goblin: Node3D = goblins[0]
	var before := _goblins().size()

	var ball: Area3D = load("res://player/fireball.tscn").instantiate()
	get_tree().current_scene.add_child(ball)
	# Fire slightly downward from above, the way you actually would mid-ride --
	# a flat shot along the ground clips whatever the goblin is standing on.
	ball.global_position = goblin.global_position + Vector3(0, 5.0, 14.0)
	ball.look_at(goblin.global_position + Vector3(0, 0.9, 0), Vector3.UP)

	for tick in 180:
		await get_tree().physics_frame
		if _goblins().size() < before:
			break
	var after := _goblins().size()
	print("  fireball: %d goblins -> %d" % [before, after])
	if after >= before:
		_failures.append("fireball did not kill the goblin")


## The fireball must leave from in front of the wizard and travel where the
## crosshair points.
##
## Spawning it at the camera instead looked right in first person and was wrong
## in third: the camera sits ~6m behind the wizard, so the fireball appeared
## behind the player and flew *parallel* to the aim rather than converging on
## it, passing beside whatever the crosshair was on.
func _check_fireball_aim() -> void:
	_player.global_position = Vector3(9000, 500, 9000)
	_player.rotation.y = PI          # face +Z
	_player.velocity = Vector3.ZERO
	await get_tree().physics_frame

	Input.action_press("attack")
	await get_tree().physics_frame
	Input.action_release("attack")
	await get_tree().physics_frame

	var balls := get_tree().current_scene.find_children("*", "Fireball", true, false)
	if balls.is_empty():
		print("  fireball aim: NONE SPAWNED")
		_failures.append("pressing attack spawned no fireball")
		return
	var ball: Node3D = balls[0]
	var spawn: Vector3 = ball.global_position
	var ahead: float = spawn.z - _player.global_position.z
	var start := spawn
	for tick in 40:
		await get_tree().physics_frame
		if not is_instance_valid(ball):
			break
	if not is_instance_valid(ball):
		print("  fireball aim: died early")
		_failures.append("fireball vanished before travelling")
		return
	var dir := (ball.global_position - start).normalized()
	print("  fireball aim: spawned %.1fm ahead of the player, direction %s" % [
		ahead, str(dir.snapped(Vector3.ONE * 0.01))])
	if ahead < 0.5:
		_failures.append("fireball spawns behind the player (%.1fm)" % ahead)
	if dir.z < 0.95:
		_failures.append("fireball does not travel forward: %s" % str(dir))


## Killing a goblin must drop coins, and those coins must be collectable at the
## speeds you actually travel at.
func _check_coins_drop_and_collect() -> void:
	var goblins := _goblins()
	if goblins.is_empty():
		return
	var goblin: GoblinArcher = goblins[0]
	# Park far away so the magnet does not grab them before we have counted.
	_player.global_position = Vector3(20000, 500, 20000)
	_player.velocity = Vector3.ZERO
	_player.reset_score()
	var at := goblin.global_position
	goblin.die()
	await get_tree().physics_frame

	var coins := get_tree().current_scene.find_children("*", "Coin", true, false)
	print("  goblin dropped %d coins, kills now %d" % [coins.size(), _player.get_kills()])
	if coins.is_empty():
		_failures.append("dead goblin dropped no coins")
		return
	if _player.get_kills() < 1:
		_failures.append("kill was not counted")

	# Fly past at surf speed and check they are actually picked up.
	_player.global_position = at + Vector3(0, 1.0, -25.0)
	_player.velocity = Vector3(0, 0, 30.0)
	# Run the whole fly-by rather than stopping at the first pickup: the
	# question is not "can a coin be collected" but "does a pass at speed sweep
	# up the pile", which is what makes killing things feel worth doing.
	for tick in 240:
		await get_tree().physics_frame
	print("  collected %d gold on one pass at 30 m/s" % _player.get_coins())
	if _player.get_coins() <= 0:
		_failures.append("coins could not be collected at speed")


## Firing while pressed against a ramp must work. This is where you spend most
## of the game, so it is where most shots are taken.
##
## It did not work: the fireball's hit sphere was big enough to overlap the wall
## being surfed, so it detonated on spawn. Every shot taken while riding
## vanished, and the only place shooting functioned was standing on a flat pad.
func _check_firing_while_surfing() -> void:
	# On the face of level 1's first left ramp.
	_player.global_position = Vector3(-20.4, 15.7, 20.0)
	_player.rotation.y = PI
	_player.velocity = Vector3(0, 0, 22.0)
	for tick in 30:
		await get_tree().physics_frame

	Input.action_press("attack")
	await get_tree().physics_frame
	Input.action_release("attack")
	var balls := get_tree().current_scene.find_children("*", "Fireball", true, false)
	if balls.is_empty():
		print("  firing off a ramp: NO FIREBALL")
		_failures.append("no fireball spawned while on a ramp")
		return
	var ball: Node3D = balls[0]
	var start: Vector3 = ball.global_position
	for tick in 60:
		await get_tree().physics_frame
		if not is_instance_valid(ball):
			break
	if not is_instance_valid(ball):
		print("  firing off a ramp: DETONATED IMMEDIATELY")
		_failures.append("fireball dies on spawn when fired from a ramp")
		return
	var travelled := ball.global_position.distance_to(start)
	print("  firing off a ramp: travelled %.0fm" % travelled)
	if travelled < 20.0:
		_failures.append("fireball barely moved off a ramp (%.0fm)" % travelled)


## A fireball should carry until it hits something, not expire in mid-air.
func _check_long_range_kill() -> void:
	var goblin: GoblinArcher = load("res://blocks/goblin_archer.tscn").instantiate()
	_main.add_child(goblin)
	goblin.global_position = Vector3(40000, 300, 40300)
	await get_tree().physics_frame

	var ball: Area3D = load("res://player/fireball.tscn").instantiate()
	get_tree().current_scene.add_child(ball)
	ball.global_position = Vector3(40000, 301, 40000)   # 300m short of the target
	ball.look_at(goblin.global_position + Vector3(0, 0.9, 0), Vector3.UP)

	var killed := false
	for tick in 400:
		await get_tree().physics_frame
		if not is_instance_valid(goblin) or goblin._dying:
			killed = true
			break
	print("  300m shot: killed the goblin: %s" % str(killed))
	if not killed:
		_failures.append("fireball could not reach a target 300m away")
