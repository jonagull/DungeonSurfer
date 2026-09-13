extends Control
class_name SpeedLines

## Radial streaks that rush outward from the centre of the screen when you are
## moving fast through the air.
##
## Surf has no other cue for speed once the scenery is far away: the camera FOV
## widens but the world can be empty for hundreds of metres, so 800 u/s and
## 2500 u/s look nearly identical. These give the top end somewhere to go.

## Speed (m/s) at which streaks start appearing.
@export var start_speed := 18.0
## Speed at which they reach full strength.
@export var full_speed := 55.0
@export var line_count := 56
@export var color := Color(1, 1, 1, 0.5)
## Streaks are drawn outside this fraction of the screen's half-diagonal, so the
## middle of the view stays clear and you can still see where you are going.
@export_range(0.1, 0.95, 0.01) var clear_radius := 0.42

var _strength := 0.0
var _scroll := 0.0
var _angles: PackedFloat32Array = []
var _lengths: PackedFloat32Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Fixed spread, so the streaks sit still relative to each other and only
	# their length and travel animate. Re-randomising every frame reads as
	# static rather than motion.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260911
	for i in line_count:
		_angles.append(rng.randf() * TAU)
		_lengths.append(rng.randf_range(0.5, 1.0))


## Called by the HUD each frame.
func set_speed(speed: float, airborne: bool) -> void:
	var raw := clampf((speed - start_speed) / maxf(full_speed - start_speed, 0.01), 0.0, 1.0)
	# Mostly an airborne effect; on foot it is only a hint, so sprinting across
	# a pad does not white out the screen.
	var target := raw if airborne else raw * 0.25
	_strength = lerpf(_strength, target, 0.12)
	_scroll = fmod(_scroll + (0.35 + 2.2 * _strength) * get_process_delta_time(), 1.0)
	queue_redraw()


func _draw() -> void:
	if _strength <= 0.01:
		return
	var centre := size * 0.5
	var reach := centre.length()
	var inner := reach * clear_radius
	for i in _angles.size():
		var dir := Vector2(cos(_angles[i]), sin(_angles[i]))
		# Each streak marches outward on its own offset and wraps around.
		var travel: float = fmod(_scroll + float(i) / float(_angles.size()), 1.0)
		var start := inner + (reach - inner) * travel
		var length := reach * 0.22 * _lengths[i] * _strength
		if start + length > reach * 1.15:
			length = maxf(reach * 1.15 - start, 0.0)
		if length <= 0.0:
			continue
		# Fade in as it leaves the clear zone and out again at the edge.
		var fade: float = sin(travel * PI)
		var col := color
		col.a = color.a * _strength * fade
		draw_line(centre + dir * start, centre + dir * (start + length), col,
			maxf(1.0, 2.4 * _strength), true)
