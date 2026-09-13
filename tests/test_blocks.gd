extends Node
# Checks every block scene builds, and that the three with runtime behaviour
# actually change the player. A pad that silently does nothing looks identical
# to a pad you placed slightly wrong, which is a miserable thing to debug in
# the editor.

var _main: Node
var _player: SurfPlayer
var _failures: Array[String] = []


func _ready() -> void:
	_main = load("res://main.tscn").instantiate()
	add_child(_main)
	_player = _main.get_node("Player")
	await get_tree().physics_frame

	await _check_all_build()
	await _check_bounce()
	await _check_boost()
	await _check_hazard()

	print("")
	if _failures.is_empty():
		print("PASS")
	else:
		for f in _failures:
			print("FAIL: " + f)
	get_tree().quit()


func _fail(msg: String) -> void:
	_failures.append(msg)


## Every block must generate its collision and visuals on load.
func _check_all_build() -> void:
	for name in ["ramp", "platform", "wave", "bounce_pad", "boost_pad", "hazard", "finish", "decor"]:
		var scene: PackedScene = load("res://blocks/%s.tscn" % name)
		if scene == null:
			_fail("blocks/%s.tscn will not load" % name)
			continue
		var node: Node = scene.instantiate()
		_main.add_child(node)
		await get_tree().physics_frame
		var built := node.get_child_count()
		print("  %-12s builds %d child node(s)" % [name, built])
		if built == 0:
			_fail("blocks/%s.tscn builds nothing" % name)
		if name == "wave" and built != 2:
			_fail("wave should build 2 ramps, built %d" % built)
		node.queue_free()
	await get_tree().physics_frame


## Drop the player onto a pad parked in empty space, away from the level.
func _drop_on(node: Node3D, at: Vector3) -> void:
	node.position = at
	_main.add_child(node)
	_player.global_position = at + Vector3(0.0, 3.0, 0.0)
	_player.velocity = Vector3.ZERO
	await get_tree().physics_frame


func _check_bounce() -> void:
	var pad: SurfBouncePad = load("res://blocks/bounce_pad.tscn").instantiate()
	await _drop_on(pad, Vector3(2000, 200, 2000))
	var peak := -999.0
	for tick in 90:
		await get_tree().physics_frame
		peak = maxf(peak, _player.velocity.y)
	print("  bounce pad: peak vertical speed %.1f (launch %.1f)" % [peak, pad.launch])
	if peak < pad.launch - 1.0:
		_fail("bounce pad did not launch the player")
	pad.queue_free()


func _check_boost() -> void:
	var pad: SurfBoostPad = load("res://blocks/boost_pad.tscn").instantiate()
	await _drop_on(pad, Vector3(3000, 200, 3000))
	var best := 0.0
	for tick in 90:
		await get_tree().physics_frame
		best = maxf(best, _player.get_horizontal_speed())
	print("  boost pad:  peak horizontal speed %.1f (boost %.1f)" % [best, pad.boost])
	if best < pad.boost - 1.0:
		_fail("boost pad did not push the player")
	pad.queue_free()


func _check_hazard() -> void:
	var hazard: SurfHazard = load("res://blocks/hazard.tscn").instantiate()
	hazard.size = Vector3(40, 10, 40)
	await _drop_on(hazard, Vector3(4000, 200, 4000))
	var moved := false
	for tick in 120:
		await get_tree().physics_frame
		if _player.global_position.distance_to(Vector3(4000, 203, 4000)) > 200.0:
			moved = true
			break
	print("  hazard:     respawned the player: %s" % str(moved))
	if not moved:
		_fail("hazard did not respawn the player")
	hazard.queue_free()
