extends Node
# Structural check on Level 1.
#
# Deliberately not a surf AI. A bot good enough to actually play a platforming
# level is its own project, and when it fails you cannot tell whether the level
# or the bot is at fault -- which is exactly the trap that hid a reversed
# zigzag here. These checks are instead things that must hold regardless of
# skill: every checkpoint has to catch a player who just falls from it, and the
# gate has to fire when crossed.

const MAP := "Castle Approach"
var _player: SurfPlayer
var _course: SurfCourse
var _goal_fired := false
var _failures: Array[String] = []


func _ready() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	_player = main.get_node("Player")
	_course = main.get_node("Course")
	_course.reached_goal.connect(func() -> void: _goal_fired = true)
	_course.build_map(_course.index_of(MAP))
	await get_tree().physics_frame
	print("map: %s  (%d checkpoints)" % [_course.map_name(), _course.checkpoints.size()])

	await _check_checkpoints_catch()
	await _check_goal_fires()

	print("")
	if _failures.is_empty():
		print("PASS")
	else:
		for f in _failures:
			print("FAIL: " + f)
	get_tree().quit()


## Drop the player from each checkpoint with a shove down-course and require
## that the level catches them. A checkpoint you fall straight out of is an
## unrecoverable respawn loop, which no amount of skill fixes.
func _check_checkpoints_catch() -> void:
	for i in _course.checkpoints.size():
		_player.respawn(i)
		_player.velocity = Vector3(0.0, 0.0, 18.0)
		var caught := false
		var start_z: float = _player.global_position.z
		for tick in 300:
			await get_tree().physics_frame
			if _player.is_on_floor() or _player.is_surfing():
				caught = true
				break
		var travelled: float = _player.global_position.z - start_z
		print("  checkpoint %d: %s after %.0fm" % [
			i, "caught" if caught else "FELL THROUGH", travelled])
		if not caught:
			_failures.append("checkpoint %d drops the player into nothing" % i)


## The gate has to actually trigger, and only for the player.
func _check_goal_fires() -> void:
	_goal_fired = false
	var last: int = _course.checkpoints.size() - 1
	_player.respawn(last)
	# Reverse back through the gateway, then cross it forwards.
	_player.global_position += Vector3(0.0, 20.0, -90.0)
	_player.velocity = Vector3(0.0, 0.0, 30.0)
	for tick in 400:
		await get_tree().physics_frame
		if _goal_fired:
			break
	print("  gate trigger: %s" % ("fired" if _goal_fired else "NEVER FIRED"))
	if not _goal_fired:
		_failures.append("crossing the gateway does not finish the level")
