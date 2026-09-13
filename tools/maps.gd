class_name SurfMaps
extends RefCounted

## Course definitions. Geometry is derived from these numbers in course.gd, so
## a map is just a table -- you cannot write down a broken ramp angle here.
##
## ramp_angle must stay above the player's floor_max_angle (45) or the engine
## treats the ramp as standable ground and you walk up it instead of surfing.
##
## ramp_width is the length of the ramp face along the slope. It is the single
## biggest lever on both difficulty and top speed: it is how much vertical room
## you have to fall through before you run out of ramp, and time on the ramp is
## what speed is made of.
##
## Per segment: z (start), len, y (height of the ramps' bottom edge), gap (half
## width of the hole at the bottom of the channel) and walls.

const MAPS := [
	{
		# Tutorial. One very wide, very long wall and nothing else: no gaps to
		# clear, no enemies, no way to fall off the side. Wide ramps mean a lot
		# of vertical room to be wrong in, which is exactly what learning the
		# strafe needs.
		"name": "Basics",
		"blurb": "Tutorial -- hold one strafe key and sweep the mouse that way.",
		"ramp_angle": 48.0,
		"ramp_width": 85.0,
		"segments": [
			{"z": 0.0, "len": 260.0, "y": 0.0, "gap": 10.0, "walls": "both"},
		],
	},
	{
		# Level 1. Short carves broken up by flat pads, rather than one long
		# wave: a ramp you can hold indefinitely stops asking anything of you
		# after a few seconds. Ride a few seconds, drop onto a pad, hop off it,
		# ride again.
		#
		# Each pad butts directly against the *start* of the next ramp with no
		# gap, on purpose. The pads are where you can end up stationary, and a
		# standing jump covers far less ground than a ride does -- leave a gap
		# there and a player who stops is stranded at that checkpoint forever.
		# The gaps all sit on the ramp-to-pad side, where you arrive falling and
		# the pad is a wide target underneath you.
		"name": "Castle Approach",
		"blurb": "Level 1 -- three short carves, two pads, one gate.",
		"ramp_angle": 50.0,
		"ramp_width": 45.0,
		"segments": [
			{"z": 0.0,   "len": 55.0, "y": 0.0,   "gap": 8.0, "walls": "both"},
			{"type": "platform", "z": 70.0,  "len": 45.0, "y": -26.0, "x": 0.0, "w": 42.0},
			{"z": 115.0, "len": 55.0, "y": -46.0, "gap": 8.0, "walls": "both"},
			{"type": "platform", "z": 185.0, "len": 45.0, "y": -72.0, "x": 0.0, "w": 42.0},
			{"z": 230.0, "len": 60.0, "y": -92.0, "gap": 8.0, "walls": "both"},
		],
	},
	{
		"name": "Novice Channel",
		"blurb": "Learn the carve. Short ramps, forgiving gaps.",
		"ramp_angle": 50.0,
		"ramp_width": 60.0,
		"segments": [
			{"z": 0.0,   "len": 150.0, "y": 0.0,    "gap": 9.0,  "walls": "both"},
			{"z": 175.0, "len": 150.0, "y": -30.0,  "gap": 10.0, "walls": "both"},
			{"z": 350.0, "len": 165.0, "y": -66.0,  "gap": 9.0,  "walls": "left"},
			{"z": 540.0, "len": 165.0, "y": -106.0, "gap": 9.0,  "walls": "right"},
			{"z": 730.0, "len": 190.0, "y": -150.0, "gap": 8.0,  "walls": "both"},
		],
	},
	{
		# There is no air friction, so speed on a ramp has no terminal velocity --
		# it is bounded only by how much height you have left to trade for it
		# (v = sqrt(2*g*h)). A flat-extruded ramp caps you at its own height and
		# runs dry in seconds, so every segment here is pitched nose-down: the
		# channel keeps descending as it runs and the trade never has to stop.
		# Roughly 490m of total drop, which is about 5500 u/s of headroom.
		"name": "Velocity",
		"blurb": "Long, tall, steep. Ride high and let it build.",
		"ramp_angle": 52.0,
		"ramp_width": 120.0,
		"segments": [
			{"z": 0.0,    "len": 600.0, "y": 0.0,    "gap": 12.0, "pitch": 9.0,  "walls": "both"},
			{"z": 625.0,  "len": 600.0, "y": -120.0, "gap": 14.0, "pitch": 10.0, "walls": "both"},
			{"z": 1250.0, "len": 700.0, "y": -260.0, "gap": 12.0, "pitch": 11.0, "walls": "both"},
		],
	},
]
