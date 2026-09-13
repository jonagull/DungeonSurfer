extends Node3D

## Run state only: the clock, best times, and the map-cycling key.
##
## The world itself is authored in main.tscn -- WorldEnvironment points at
## world/sky.tres, and the Sun is a DirectionalLight3D you can select and
## adjust. Nothing here builds scenery.

@onready var _player: SurfPlayer = $Player
@onready var _course: SurfCourse = $Course
@onready var _hud: CanvasLayer = $HUD

## Run state. The timer runs from the moment a level starts, including the walk
## off the platform -- starting it on first contact with a ramp would reward
## dawdling at the top to line up a perfect drop-in.
var _run_time := 0.0
var _running := false
var _best: Dictionary = {}

## Story mode respawns you at the last checkpoint. Arcade mode does not: a fall
## ends the run. Distance is only a score if it can be taken away from you --
## with checkpoints, any distance is reachable given enough attempts.
var _arcade := false
var _best_score: Dictionary = {}


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_player.course = _course
	_hud.player = _player
	_hud.course = _course
	_course.reached_goal.connect(_on_reached_goal)
	# Portals and the map key both land here, so a fresh level always means a
	# fresh run.
	_course.level_changed.connect(_start_run)
	_player.fell.connect(_on_player_fell)
	# Course built its checkpoints during its own _ready, so this is safe here.
	_start_run()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cycle_map"):
		_course.next_map()
	elif event.is_action_pressed("go_lobby"):
		_course.build_map(_course.index_of("Lobby"))
	elif event.is_action_pressed("restart_course"):
		_start_run()
	elif event.is_action_pressed("toggle_mode"):
		_arcade = not _arcade
		_start_run()


func _start_run() -> void:
	_player.respawn(0)
	_player.reset_score()
	_run_time = 0.0
	_running = true
	_hud.clear_finish()


## A run ends one of two ways: you clear the gate, or you fall.
func _on_reached_goal() -> void:
	if not _running:
		return
	_running = false
	var previous: float = _best.get(_course.map_index, 0.0)
	var is_record: bool = previous <= 0.0 or _run_time < previous
	if is_record:
		_best[_course.map_index] = _run_time
	_hud.show_finish("GATE CLEARED", _run_time, is_record, _summary(), _arcade)


func _on_player_fell() -> void:
	if not _running:
		if not _arcade:
			_player.respawn(_player.get_checkpoint())
		return
	if not _arcade:
		# Story mode: a fall costs you a few seconds, not the run.
		_player.respawn(_player.get_checkpoint())
		return
	_running = false
	var score := _score()
	var previous: int = _best_score.get(_course.map_index, 0)
	if score > previous:
		_best_score[_course.map_index] = score
	_hud.show_finish("YOU FELL", _run_time, score > previous, _summary(), _arcade)


## One number to beat, so a run is comparable to the last one.
func _score() -> int:
	return int(_player.get_distance()) + _player.get_kills() * 50 + _player.get_coins() * 10


func _summary() -> String:
	var lines := "%dm travelled    %d slain    %d gold" % [
		int(_player.get_distance()), _player.get_kills(), _player.get_coins()]
	lines += "\ntop speed %d u/s" % roundi(_player.get_best_speed() * 39.37)
	if _arcade:
		var best: int = _best_score.get(_course.map_index, 0)
		lines += "\n\nSCORE %d" % _score()
		if best > 0:
			lines += "    (best %d)" % best
	return lines


func _process(delta: float) -> void:
	if _running:
		_run_time += delta
	_hud.set_run(_run_time, _running, _best.get(_course.map_index, 0.0), _arcade)
