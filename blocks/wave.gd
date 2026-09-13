@tool
extends Node3D
class_name SurfWave

## A wave: the facing pair of ramps that makes a channel. This is the piece you
## place over and over, so it is one node with one set of numbers rather than
## two ramps you have to keep mirrored by hand.
##
## Origin sits in the middle of the channel, on the line where both ramps have
## their low edge. Drop it where you want the bottom of the wave.

const RAMP := preload("res://blocks/ramp.tscn")

enum Walls { BOTH, LEFT_ONLY, RIGHT_ONLY }

## Which walls exist. Single walls are the harder, more interesting shape: fall
## off one and you have to cross to the next. Note that riding a left wall
## slides you rightwards, so a left wall should be followed by a right one.
@export var walls: int = Walls.BOTH:
	set(v):
		walls = v
		_rebuild()

## Half the width of the hole at the bottom of the channel.
@export_range(0.0, 120.0, 0.5) var gap := 8.0:
	set(v):
		gap = v
		_rebuild()

## Must stay steeper than the player's floor_max_angle (45) or the faces become
## standable ground and you walk up them instead of surfing.
@export_range(30.0, 80.0, 0.5) var angle := 50.0:
	set(v):
		angle = v
		_rebuild()

## Length of each face up the slope: how much room there is to recover.
@export_range(5.0, 300.0, 1.0) var width := 45.0:
	set(v):
		width = v
		_rebuild()

@export_range(5.0, 800.0, 1.0) var length := 55.0:
	set(v):
		length = v
		_rebuild()


func _ready() -> void:
	_rebuild()


## Height of the ramp tops above this node.
func rise() -> float:
	return width * sin(deg_to_rad(angle))


## How far the tops lean out to either side.
func run() -> float:
	return width * cos(deg_to_rad(angle))


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for child in get_children():
		if child.owner == null:
			remove_child(child)
			child.queue_free()

	if walls != Walls.RIGHT_ONLY:
		_ramp(-gap, SurfRamp.LEFT_WALL, "RampLeft")
	if walls != Walls.LEFT_ONLY:
		_ramp(gap, SurfRamp.RIGHT_WALL, "RampRight")


func _ramp(x: float, side: int, name: String) -> void:
	var ramp: SurfRamp = RAMP.instantiate()
	ramp.name = name
	ramp.position = Vector3(x, 0.0, 0.0)
	ramp.angle = angle
	ramp.width = width
	ramp.length = length
	ramp.side = side
	add_child(ramp)
