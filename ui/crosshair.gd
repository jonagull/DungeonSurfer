extends Control
class_name Crosshair

## Four ticks around a centre dot. Whatever it covers is what a fireball hits --
## the player raycasts through this exact point.
##
## It moves for two reasons, both of them information: it kicks open when you
## fire and closes as the next shot comes ready, and it tightens when you zoom.

@export var color := Color(1, 1, 1, 0.8)
@export var tick_length := 9.0
@export var thickness := 2.0
## Gap between the centre and each tick, when idle.
@export var rest_gap := 7.0
## Gap immediately after firing.
@export var fire_gap := 18.0
@export var zoom_gap := 4.0

var _gap := 7.0
var _dot_alpha := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## `ready_fraction` is 0 straight after a shot and 1 when the next is loaded.
func set_state(ready_fraction: float, zooming: bool) -> void:
	var target := lerpf(fire_gap, zoom_gap if zooming else rest_gap, ready_fraction)
	_gap = lerpf(_gap, target, 0.25)
	# The dot dims while reloading, so "can I shoot" is readable without
	# looking away from where you are going.
	_dot_alpha = lerpf(_dot_alpha, 0.25 + 0.75 * ready_fraction, 0.25)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + dir * _gap, c + dir * (_gap + tick_length), color, thickness)
	var dot := color
	dot.a = color.a * _dot_alpha
	draw_circle(c, thickness * 0.9, dot)
