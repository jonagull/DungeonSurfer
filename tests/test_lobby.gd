extends Node
# The lobby is hand-authored, so the risks are wiring, not geometry: a portal
# with no target, a vendor with no lines, a spawn point inside a wall.

var _main: Node
var _player: SurfPlayer
var _course: SurfCourse
var _failures: Array[String] = []


func _ready() -> void:
	_main = load("res://main.tscn").instantiate()
	add_child(_main)
	_player = _main.get_node("Player")
	_course = _main.get_node("Course")
	await get_tree().physics_frame

	await _check_lobby_loads_first()
	await _check_spawn_is_solid()
	await _check_portals()
	await _check_vendor()
	await _check_portal_travel()

	print("")
	if _failures.is_empty():
		print("PASS")
	else:
		for f in _failures:
			print("FAIL: " + f)
	get_tree().quit()


func _check_lobby_loads_first() -> void:
	print("  starting level: %s" % _course.map_name())
	if _course.map_name() != "The Lobby":
		_failures.append("game does not start in the lobby")


## You should land on the floor, not fall through it or spawn inside a wall.
func _check_spawn_is_solid() -> void:
	_player.respawn(0)
	_player.velocity = Vector3.ZERO
	for tick in 240:
		await get_tree().physics_frame
		if _player.is_on_floor():
			break
	print("  spawn: standing on floor after drop: %s (y=%.1f)" % [
		str(_player.is_on_floor()), _player.global_position.y])
	if not _player.is_on_floor():
		_failures.append("player does not land on the lobby floor")


func _check_portals() -> void:
	var portals := _main.find_children("*", "Portal", true, false)
	var wired := 0
	for node in portals:
		var portal := node as Portal
		if portal.target_level != null:
			wired += 1
	print("  portals: %d placed, %d wired to a level" % [portals.size(), wired])
	if portals.size() < 6:
		_failures.append("expected 6 portals, found %d" % portals.size())
	if wired < 4:
		_failures.append("only %d portals lead anywhere" % wired)


func _check_vendor() -> void:
	var vendors := _main.find_children("*", "Vendor", true, false)
	if vendors.is_empty():
		print("  vendor: MISSING")
		_failures.append("no vendor in the lobby")
		return
	var vendor := vendors[0] as Vendor
	print("  vendor: '%s' with %d lines" % [vendor.vendor_name, vendor.lines.size()])
	if vendor.lines.is_empty():
		_failures.append("vendor has nothing to say")

	# Standing next to it should raise the prompt.
	_player.global_position = vendor.global_position + Vector3(3, 1, 3)
	_player.velocity = Vector3.ZERO
	for tick in 10:
		await get_tree().physics_frame
	var box := get_tree().get_first_node_in_group("dialogue")
	var talked := false
	if box != null:
		Input.action_press("interact")
		await get_tree().physics_frame
		Input.action_release("interact")
		await get_tree().physics_frame
		talked = box._panel.visible
	print("  vendor: dialogue opened on E: %s" % str(talked))
	if not talked:
		_failures.append("pressing E next to the vendor said nothing")


## Walking into a portal must actually change level.
func _check_portal_travel() -> void:
	var portals := _main.find_children("*", "Portal", true, false)
	var target: Portal = null
	for node in portals:
		if (node as Portal).target_level != null:
			target = node
			break
	if target == null:
		return
	var before := _course.map_name()
	_player.global_position = target.global_position + Vector3(0, 2, 0)
	_player.velocity = Vector3.ZERO
	for tick in 300:
		await get_tree().physics_frame
		if _course.map_name() != before:
			break
	print("  portal travel: %s -> %s" % [before, _course.map_name()])
	if _course.map_name() == before:
		_failures.append("walking into a portal did not change level")
