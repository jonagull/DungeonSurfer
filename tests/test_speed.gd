extends Node
# Rides a map with an *optimal* strafe bot to find the real top speed.
#
# The cap makes this subtle: acceleration only pays out while
# velocity.dot(wish_dir) < air_cap, so at speed v the wish direction has to sit
# within acos(air_cap/v) of perpendicular to your velocity -- a window that
# narrows as 1/v. That is precisely the skill a human is exercising with the
# mouse. The bot below tracks that edge exactly, so what it reaches is roughly
# the map's ceiling.
@export var map_name := "Velocity"
var _player: SurfPlayer
var _course: SurfCourse
var _t := 0

func _ready() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	_player = main.get_node("Player")
	_course = main.get_node("Course")
	await get_tree().physics_frame
	_course.build_map(_course.index_of(map_name))
	await get_tree().physics_frame
	print("map: ", _course.map_name())
	_player.respawn(1)          # top of the first ramp
	_player.velocity = Vector3(0, 0, 20.0)
	Input.action_press("move_right")

func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	_aim()
	_t += 1
	if _t % 240 == 0:
		var p := _player.global_position
		print("t=%5.1fs spd=%7.2f m/s (%6d u/s) pos=(%7.1f,%7.1f,%8.1f) surf=%s" % [
			_t / 120.0, _player.get_horizontal_speed(),
			roundi(_player.get_horizontal_speed() * 39.37),
			p.x, p.y, p.z, str(_player.is_surfing())])
	if _t >= 3600:
		print("RESULT best=%d u/s" % roundi(_player.get_best_speed() * 39.37))
		get_tree().quit()

## Point the strafe just inside the speed cap, on whichever side is up-slope.
func _aim() -> void:
	var vh := Vector3(_player.velocity.x, 0.0, _player.velocity.z)
	if vh.length() < 0.5:
		return
	var dir := vh.normalized()
	# Up-slope is whichever horizontal way the ramp we are on leans.
	var n := _player.get_surface_normal()
	var side := Vector3(-signf(n.x), 0.0, 0.0) if absf(n.x) > 0.01 else Vector3(-1, 0, 0)
	var perp := (side - dir * side.dot(dir))
	if perp.length() < 0.01:
		return
	perp = perp.normalized()
	# Trade speed gain for altitude as we approach the bottom of the ramp,
	# otherwise the bot dives straight through the channel in a few seconds.
	var low := clampf((50.0 - absf(_player.global_position.x)) / 50.0, 0.0, 1.0)
	var cos_psi: float = minf(0.92 * _player.air_cap / maxf(vh.length(), 0.1), 0.99) * (1.0 - low)
	var d := (dir * cos_psi + perp * sqrt(1.0 - cos_psi * cos_psi)).normalized()
	_player.rotation.y = atan2(-d.z, d.x)
