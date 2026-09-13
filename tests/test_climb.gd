extends Node
# Can a rider hold or gain altitude by strafing up-slope? If not, every segment
# is a slow inevitable slide into the gap and the course is unplayable.
var _player: SurfPlayer
var _t := 0

func _ready() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	_player = main.get_node("Player")
	var course: SurfCourse = main.get_node("Course")
	course.build_map(course.index_of("Novice Channel"))
	await get_tree().physics_frame
	_player.global_position = Vector3(-24.3, 19.8, 20.0)
	_player.rotation.y = PI          # face +Z, down the course
	_player.velocity = Vector3(0, 0, 30.0)
	Input.action_press("move_right") # strafe toward -X = up the left wall
	print("start y=19.8")

func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	_t += 1
	if _t % 60 == 0:
		var p := _player.global_position
		print("t=%4.1fs y=%7.2f z=%7.1f vz=%6.2f spd=%6.2f (%5d u/s) surf=%s" % [
			_t / 120.0, p.y, p.z, _player.velocity.z,
			_player.get_horizontal_speed(),
			roundi(_player.get_horizontal_speed() * 39.37), str(_player.is_surfing())])
	if _t >= 600:
		get_tree().quit()
