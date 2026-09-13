extends CanvasLayer

## Speedometer. Surf is a game about a number going up, so the number needs to
## be legible at a glance and react instantly.

## Source unit conversion, so the numbers read like CS speeds (250 = walking,
## 1000+ = actually surfing). Purely cosmetic.
const UNITS_PER_METRE := 39.37
const BAR_MAX_SPEED := 110.0

var player: SurfPlayer = null
var course: SurfCourse = null

var _speed_label: Label
var _state_label: Label
var _best_label: Label
var _bar: ColorRect
var _bar_bg: ColorRect
var _map_label: Label
var _time_label: Label
@onready var _speed_lines: SpeedLines = $SpeedLines
@onready var _crosshair: Crosshair = $Crosshair
var _finish_label: Label
var _hit_flash: ColorRect
var _score_label: Label
var _mult_label: Label


func _ready() -> void:
	var help := _label(16, Color(1, 1, 1, 0.55))
	help.position = Vector2(24, 20)
	help.text = "WASD move   SHIFT sprint / air-dash   LMB fireball   RMB zoom   MOUSE look   SPACE jump/bhop   V view   M map   R checkpoint   T restart   ESC cursor"

	_map_label = _label(20, Color(1, 1, 1, 0.7))
	_map_label.position = Vector2(24, 46)

	_hit_flash = ColorRect.new()
	_hit_flash.color = Color(0.85, 0.15, 0.15, 0.0)
	_hit_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hit_flash)

	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(0, 0, 0, 0.35)
	_bar_bg.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bar_bg.position = Vector2(-190, -92)
	_bar_bg.size = Vector2(380, 6)
	add_child(_bar_bg)

	_bar = ColorRect.new()
	_bar.color = Color(0.55, 0.85, 1.0)
	_bar.position = Vector2.ZERO
	_bar.size = Vector2(0, 6)
	_bar_bg.add_child(_bar)

	_speed_label = _label(54, Color(1, 1, 1, 0.95))
	_speed_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_speed_label.position = Vector2(-190, -84)
	_speed_label.size = Vector2(380, 66)
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_state_label = _label(18, Color(1, 1, 1, 0.6))
	_state_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_state_label.position = Vector2(-190, -22)
	_state_label.size = Vector2(380, 24)
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_time_label = _label(30, Color(1, 1, 1, 0.85))
	_time_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_time_label.position = Vector2(-160, 18)
	_time_label.size = Vector2(320, 38)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_finish_label = _label(40, Color(1.0, 0.86, 0.5))
	_finish_label.set_anchors_preset(Control.PRESET_CENTER)
	_finish_label.position = Vector2(-320, -110)
	_finish_label.size = Vector2(640, 220)
	_finish_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_finish_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_finish_label.visible = false

	_score_label = _label(24, Color(1, 0.84, 0.35))
	_score_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_score_label.position = Vector2(-260, 46)
	_score_label.size = Vector2(236, 28)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_mult_label = _label(26, Color(1, 0.86, 0.35))
	_mult_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_mult_label.position = Vector2(-190, -122)
	_mult_label.size = Vector2(380, 30)
	_mult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_best_label = _label(18, Color(1, 1, 1, 0.45))
	_best_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_best_label.position = Vector2(-260, 20)
	_best_label.size = Vector2(236, 24)
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("shadow_offset_y", 2)
	add_child(l)
	return l


func _process(_delta: float) -> void:
	if player == null:
		return
	if course != null:
		_map_label.text = "%s  --  %s" % [course.map_name(), course.map_blurb()]
	var speed := player.get_horizontal_speed()
	_speed_lines.set_speed(speed, not player.is_on_floor())
	_hit_flash.color.a = player.get_hit_fx() * 0.28
	_crosshair.set_state(player.get_fire_ready(), player.is_zooming())
	var mult := player.get_multiplier()
	_score_label.text = "%dm    %d gold    %d slain" % [
		int(player.get_distance()), player.get_coins(), player.get_kills()]
	# The multiplier only earns screen space once it is actually above 1.
	_mult_label.text = "x%d gold" % mult if mult > 1 else ""
	_mult_label.add_theme_color_override("font_color",
		Color(1.0, 0.86, 0.35).lerp(Color(1.0, 0.45, 0.25), (mult - 1) / 4.0))
	_speed_label.text = "%d" % roundi(speed * UNITS_PER_METRE)
	_best_label.text = "best  %d" % roundi(player.get_best_speed() * UNITS_PER_METRE)

	var t := clampf(speed / BAR_MAX_SPEED, 0.0, 1.0)
	_bar.size.x = _bar_bg.size.x * t
	_bar.color = Color(0.55, 0.85, 1.0).lerp(Color(1.0, 0.72, 0.35), t)

	if player.is_surfing():
		_state_label.text = "SURFING"
		_state_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.42))
	elif player.is_on_floor():
		_state_label.text = "grounded"
		_state_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	else:
		_state_label.text = "air"
		_state_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0, 0.7))


static func format_time(seconds: float) -> String:
	return "%d:%05.2f" % [int(seconds) / 60, fmod(seconds, 60.0)]


func set_run(run_time: float, running: bool, best_time: float, arcade: bool) -> void:
	var text := format_time(run_time)
	if best_time > 0.0:
		text += "     best %s" % format_time(best_time)
	text += "     %s" % ("ARCADE" if arcade else "STORY")
	_time_label.text = text
	_time_label.add_theme_color_override(
		"font_color", Color(1, 1, 1, 0.85) if running else Color(1.0, 0.86, 0.5)
	)


func show_finish(title: String, run_time: float, is_record: bool, summary: String,
		arcade: bool) -> void:
	_finish_label.text = "%s\n\n%s%s\n%s\n\nT to run again    M for next map" % [
		title,
		format_time(run_time),
		"   NEW BEST" if is_record else "",
		summary,
	]
	_finish_label.add_theme_color_override(
		"font_color", Color(1.0, 0.55, 0.45) if title == "YOU FELL" else Color(1.0, 0.86, 0.5)
	)
	_finish_label.visible = true


func clear_finish() -> void:
	_finish_label.visible = false
