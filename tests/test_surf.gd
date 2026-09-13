extends Node
# Full-loop check: spawn on the start platform, walk off it, then ride.
const TICKS := 1440
var _player: SurfPlayer
var _t := 0
var _riding := false
var _landed := false

func _ready() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	_player = main.get_node("Player")
	var course: SurfCourse = main.get_node("Course")
	course.build_map(course.index_of("Novice Channel"))
	# Respawn after the rebuild: main already spawned us using the default
	# map's checkpoints, which are somewhere else entirely.
	_player.respawn(0)
	await get_tree().physics_frame
	print("spawn=", _player.global_position)
	Input.action_press("move_forward")

func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_t += 1
	# Walk forward until we leave the platform, then ride the left wall.
	if _player.is_on_floor():
		_landed = true
	if not _riding and _landed and not _player.is_on_floor():
		_riding = true
		Input.action_release("move_forward")
		Input.action_press("move_left")
	if _riding:
		_player.rotate_y(0.42 * delta)
	if _t % 60 == 0:
		print("t=%4.1fs spd=%6.2f (%5d u/s) pos=(%7.1f,%7.1f,%7.1f) floor=%s surf=%s cp=%d" % [
			_t / 120.0, _player.get_horizontal_speed(),
			roundi(_player.get_horizontal_speed() * 39.37),
			_player.global_position.x, _player.global_position.y, _player.global_position.z,
			str(_player.is_on_floor()), str(_player.is_surfing()), _player.get_checkpoint()])
	if _t >= TICKS:
		print("RESULT best=%d u/s" % roundi(_player.get_best_speed() * 39.37))
		get_tree().quit()
