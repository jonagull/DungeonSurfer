extends RefCounted
class_name SurfLevelBuilder

## Turns a table from maps.gd into a tree of editable nodes.
##
## Authoring-time only: the bake tool runs this once and saves the result as a
## scene, and from then on the scene is the source of truth. The tables are a
## way to rough out a layout quickly, not something the game reads at runtime.

# The block *scenes*, not their scripts: a baked level then references
# blocks/ramp.tscn, so editing that scene updates every ramp in every level.
const RAMP := preload("res://blocks/ramp.tscn")
const PLATFORM := preload("res://blocks/platform.tscn")
const FINISH := preload("res://blocks/finish.tscn")
const DECOR := preload("res://blocks/decor.tscn")
const CHECKPOINT := preload("res://blocks/checkpoint.tscn")
const LEVEL := preload("res://course/level.gd")


static func build(map: Dictionary) -> Node3D:
	var root: Node3D = LEVEL.new()
	root.name = "Level"
	root.level_name = map["name"]
	root.blurb = map["blurb"]

	var a: float = deg_to_rad(map["ramp_angle"])
	var width: float = map["ramp_width"]
	var segments: Array = map["segments"]
	var run := width * cos(a)
	var rise := width * sin(a)

	var markers: Array[Vector3] = []

	# Start platform, level with the top of the first ramp and just inboard of
	# its edge, so walking forward drops you onto the face.
	var first: Dictionary = segments[0]
	var start_x: float = -first["gap"] - run
	var start_y: float = first["y"] + rise
	_platform(root, "StartPad", Vector3(start_x - 6.0, start_y, -20.0), Vector3(30.0, 3.0, 40.0))
	markers.append(Vector3(start_x + 4.0, start_y + 2.0, -16.0))

	var index := 0
	for seg: Dictionary in segments:
		index += 1
		var length: float = seg["len"]

		if seg.get("type", "ramp") == "platform":
			var px: float = seg.get("x", 0.0)
			var pw: float = seg.get("w", 32.0)
			_platform(root, "Pad%d" % index,
				Vector3(px, seg["y"] + 2.0, seg["z"] + length * 0.5),
				Vector3(pw, 4.0, length))
			# Offset from centre: dead centre sits above the hole between the
			# next pair of ramps, so respawning there and walking forward drops
			# you straight through it.
			markers.append(Vector3(px - pw * 0.28, seg["y"] + 4.0, seg["z"] + 6.0))
			continue

		var gap: float = seg["gap"]
		var walls: String = seg["walls"]
		var pitch: float = deg_to_rad(seg.get("pitch", 0.0))

		if walls == "both" or walls == "left":
			_ramp(root, "RampL%d" % index, Vector3(-gap, seg["y"], seg["z"]),
				pitch, map["ramp_angle"], width, length, SurfRamp.LEFT_WALL)
		if walls == "both" or walls == "right":
			_ramp(root, "RampR%d" % index, Vector3(gap, seg["y"], seg["z"]),
				pitch, map["ramp_angle"], width, length, SurfRamp.RIGHT_WALL)

		var side := 1.0 if walls != "right" else -1.0
		markers.append(Vector3(-side * (gap + run - 4.0), seg["y"] + rise + 3.0, seg["z"] + 10.0))

	# Finish. Sits close behind the last segment on purpose: riders leave a ramp
	# still carrying sideways velocity and drift outward all the way to the
	# wall, so a long run-out lets even a good line wander into stone.
	var last: Dictionary = segments[-1]
	var last_pitch: float = deg_to_rad(last.get("pitch", 0.0))
	var gap_last: float = last.get("gap", 10.0)
	var gate_z: float = last["z"] + last["len"] + 25.0
	var end_y: float = last["y"] - last["len"] * tan(last_pitch) - 14.0
	var half_w: float = gap_last + run + 25.0

	_platform(root, "EndPad", Vector3(0.0, end_y + 2.0, gate_z + 62.0),
		Vector3(half_w * 2.0 + 60.0, 4.0, 124.0))
	markers.append(Vector3(0.0, end_y + 6.0, gate_z + 45.0))

	var finish: SurfFinish = FINISH.instantiate()
	finish.name = "Finish"
	finish.position = Vector3(0.0, end_y + 2.0, gate_z)
	finish.opening_half_width = half_w
	root.add_child(finish)

	var decor: SurfDecor = DECOR.instantiate()
	decor.name = "Decor"
	decor.inner_x = gap_last + run + 40.0
	decor.outer_x = gap_last + run + 170.0
	decor.extent = Vector3(0.0, absf(end_y) + 80.0, gate_z + 60.0)
	decor.position = Vector3(0.0, first["y"], 0.0)
	root.add_child(decor)

	var holder := Node3D.new()
	holder.name = "Checkpoints"
	root.add_child(holder)
	for i in markers.size():
		var marker: Marker3D = CHECKPOINT.instantiate()
		marker.name = "CP%02d" % i
		marker.position = markers[i]
		holder.add_child(marker)

	return root


static func _ramp(root: Node3D, name: String, pos: Vector3, pitch: float,
		angle: float, width: float, length: float, side: int) -> void:
	var ramp: SurfRamp = RAMP.instantiate()
	ramp.name = name
	# A segment's pitch is just a rotation about X on each of its ramps; the
	# ramp's own tilt lives inside it, so the two never fight.
	ramp.position = pos
	ramp.rotation.x = pitch
	ramp.angle = angle
	ramp.width = width
	ramp.length = length
	ramp.side = side
	root.add_child(ramp)


static func _platform(root: Node3D, name: String, pos: Vector3, size: Vector3) -> void:
	var pad: SurfPlatform = PLATFORM.instantiate()
	pad.name = name
	pad.position = pos
	pad.size = size
	root.add_child(pad)
