extends Node
# Story mode must respawn you; arcade mode must end the run. The difference is
# the whole reason distance is a score at all, and both paths go through the
# same signal, so it is easy to break one while the other keeps working.

var _main: Node
var _player: SurfPlayer
var _failures: Array[String] = []


func _ready() -> void:
	_main = load("res://main.tscn").instantiate()
	add_child(_main)
	_player = _main.get_node("Player")
	await get_tree().physics_frame

	await _check_story_respawns()
	await _check_arcade_ends()
	await _check_distance()
	await _check_multiplier()

	print("")
	if _failures.is_empty():
		print("PASS")
	else:
		for f in _failures:
			print("FAIL: " + f)
	get_tree().quit()


func _check_story_respawns() -> void:
	_main._arcade = false
	_main._start_run()
	await get_tree().physics_frame
	var spawn := _player.global_position
	# Drop into nothing and wait out the fall timeout.
	_player.global_position = Vector3(0, -6000, 0)
	for tick in 600:
		await get_tree().physics_frame
		if _player.global_position.y > -1000.0:
			break
	var back := _player.global_position.distance_to(spawn) < 5.0
	print("  story: respawned at checkpoint: %s   run still going: %s" % [
		str(back), str(_main._running)])
	if not back:
		_failures.append("story mode did not respawn the player")
	if not _main._running:
		_failures.append("story mode ended the run on a fall")


func _check_arcade_ends() -> void:
	_main._arcade = true
	_main._start_run()
	await get_tree().physics_frame
	_player.global_position = Vector3(0, -6000, 0)
	for tick in 600:
		await get_tree().physics_frame
		if not _main._running:
			break
	print("  arcade: run ended on the fall: %s" % str(not _main._running))
	if _main._running:
		_failures.append("arcade mode did not end the run on a fall")


func _check_distance() -> void:
	_main._arcade = false
	_main._start_run()
	await get_tree().physics_frame
	var start := _player.global_position
	_player.global_position = start + Vector3(0, 0, 250.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var d := _player.get_distance()
	print("  distance after moving 250m down-course: %.0fm" % d)
	if absf(d - 250.0) > 12.0:
		_failures.append("distance read %.0f, expected ~250" % d)


func _check_multiplier() -> void:
	_player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	var slow := _player.get_multiplier()
	_player.global_position = Vector3(30000, 800, 30000)
	_player.velocity = Vector3(0, 0, 60.0)
	await get_tree().physics_frame
	var fast := _player.get_multiplier()
	print("  gold multiplier: x%d at rest, x%d at 60 m/s" % [slow, fast])
	if slow != 1 or fast <= slow:
		_failures.append("multiplier does not scale with speed (%d -> %d)" % [slow, fast])
