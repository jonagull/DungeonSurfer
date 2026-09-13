@tool
extends Node3D

## Poses the wizard rig. It builds nothing -- every mesh, pivot and material
## lives in wizard.tscn as an ordinary node you can select, retexture or replace.
##
## Procedural rather than baked clips, because every pose is a function of
## something the player is doing: how fast they are going, whether a ramp is
## holding them, which way they are carving. A canned loop cannot know any of
## that, so it reads as a puppet sliding around.

## Speed at which the animation reaches full stretch.
@export var full_speed := 40.0
## Hip swing at a sprint, degrees.
@export var stride_swing := 46.0
## How far the knee folds on the back swing, degrees.
@export var knee_bend := 62.0
## Shoulder twist against the legs. Most of what makes a run read as running.
@export var torso_twist := 13.0

@onready var _body: Node3D = $Body
@onready var _torso: Node3D = $Body/Torso
@onready var _head: Node3D = $Body/Torso/Head
@onready var _hat: Node3D = $Body/Torso/Head/Hat
@onready var _hat_tip: Node3D = $Body/Torso/Head/Hat/HatTip
@onready var _cloak: Node3D = $Body/Torso/Cloak
@onready var _cloak_low: Node3D = $Body/Torso/Cloak/CloakLow
@onready var _leg_l: Node3D = $Body/Hips/LegL
@onready var _leg_r: Node3D = $Body/Hips/LegR
@onready var _knee_l: Node3D = $Body/Hips/LegL/KneeL
@onready var _knee_r: Node3D = $Body/Hips/LegR/KneeR
@onready var _arm_l: Node3D = $Body/Torso/ArmL
@onready var _arm_r: Node3D = $Body/Torso/ArmR
@onready var _elbow_l: Node3D = $Body/Torso/ArmL/ElbowL
@onready var _elbow_r: Node3D = $Body/Torso/ArmR/ElbowR
@onready var _staff: Node3D = $Body/Torso/ArmR/ElbowR/Staff

var _phase := 0.0
## Separate clock for the run cycle: the legs must keep step with the ground
## while the cloak and hat run on the faster airborne beat.
var _stride := 0.0
var _speed := 0.0
var _surfing := false
var _grounded := true
var _was_grounded := true
var _strafe := 0.0
var _moving := false
var _squash := 0.0


## Called every physics tick by the player.
func set_state(speed: float, surfing: bool, grounded: bool, strafe: float,
		moving: bool = false) -> void:
	_speed = speed
	_surfing = surfing
	# Squash on touchdown. A landing with no compression reads as teleporting
	# onto the floor.
	if grounded and not _was_grounded:
		_squash = 1.0
	_was_grounded = grounded
	_grounded = grounded
	_strafe = strafe
	_moving = moving


func _process(delta: float) -> void:
	# Never animate in the editor: these are real saved nodes, and posing them
	# there would bake whatever frame you happened to save on.
	if Engine.is_editor_hint() or _body == null:
		return

	var t := clampf(_speed / full_speed, 0.0, 1.0)
	# Everything cycles faster the quicker you travel, which is most of what
	# sells the speed -- the poses alone read the same at 200 and 2000 u/s.
	_phase += delta * (3.0 + 11.0 * t)
	_squash = maxf(_squash - delta * 4.0, 0.0)
	var k := 1.0 - exp(-12.0 * delta)   # frame-rate independent smoothing

	var running := _grounded and _moving and _speed > 0.4
	if running:
		_run(delta, k)
	else:
		_ride(t, k)

	_cloak_and_hat(t, k)

	# Crouch into the ride, bob on foot, and compress on landing.
	var bob := 0.0
	if running:
		bob = absf(sin(_stride)) * -0.055        # one dip per footfall
	elif _grounded:
		bob = sin(_phase * 0.6) * 0.012          # idle breathing
	else:
		bob = sin(_phase * 0.5) * 0.02
	_body.position.y = lerpf(_body.position.y, bob - 0.16 * t - _squash * 0.12, k)
	_body.scale = _body.scale.lerp(
		Vector3(1.0 + _squash * 0.09, 1.0 - _squash * 0.13, 1.0 + _squash * 0.09), k)

	# Roll into the carve, on top of the tilt the player applies to the whole
	# model, and lean forward harder the faster we are going.
	_body.rotation.z = lerpf(_body.rotation.z, deg_to_rad(-9.0 * _strafe), k)
	var pitch := deg_to_rad(24.0 * clampf(_speed / 11.5, 0.0, 1.0)) if running \
		else deg_to_rad(13.0 * t)
	_body.rotation.x = lerpf(_body.rotation.x, pitch, k)


## A proper run cycle. The knee fold is what separates this from two pendulums:
## a straight leg swinging backwards reads as a mannequin being dragged.
func _run(delta: float, k: float) -> void:
	# Stride length is fixed, so the cycle speeds up with you rather than the
	# feet skating faster over the same ground.
	_stride += delta * clampf(_speed, 0.0, 14.0) * 1.5
	var gait := clampf(_speed / 11.5, 0.0, 1.0)
	var swing := deg_to_rad(lerpf(17.0, stride_swing, gait))
	var step := sin(_stride)

	_leg_l.rotation.x = lerpf(_leg_l.rotation.x, step * swing, k)
	_leg_r.rotation.x = lerpf(_leg_r.rotation.x, -step * swing, k)
	# Knees only fold on the back half of the swing, never forwards.
	var fold := deg_to_rad(knee_bend) * gait
	_knee_l.rotation.x = lerpf(_knee_l.rotation.x, -maxf(0.0, -step) * fold, k)
	_knee_r.rotation.x = lerpf(_knee_r.rotation.x, -maxf(0.0, step) * fold, k)

	# Arms counter-swing against the legs, elbows carried bent.
	_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -step * swing * 0.75, k)
	_arm_r.rotation.x = lerpf(_arm_r.rotation.x, step * swing * 0.75, k)
	_arm_l.rotation.z = lerpf(_arm_l.rotation.z, deg_to_rad(-10.0), k)
	_arm_r.rotation.z = lerpf(_arm_r.rotation.z, deg_to_rad(10.0), k)
	var elbow := deg_to_rad(-32.0 - 22.0 * gait)
	_elbow_l.rotation.x = lerpf(_elbow_l.rotation.x, elbow, k)
	_elbow_r.rotation.x = lerpf(_elbow_r.rotation.x, elbow, k)
	_staff.rotation.x = lerpf(_staff.rotation.x, deg_to_rad(-14.0), k)

	# Shoulders twist against the hips, and the head holds its line against the
	# shoulders. Cheap, and it is most of what makes a run look like a run.
	_torso.rotation.y = lerpf(_torso.rotation.y, -step * deg_to_rad(torso_twist), k)
	_head.rotation.y = lerpf(_head.rotation.y, step * deg_to_rad(torso_twist * 0.7), k)
	_head.rotation.x = lerpf(_head.rotation.x, deg_to_rad(-12.0), k)


## Riding, or simply airborne: legs braced apart, arms out for balance. A
## jogging motion while pinned to a ramp face looks absurd.
func _ride(t: float, k: float) -> void:
	var brace := deg_to_rad(lerpf(5.0, 20.0, t))
	_leg_l.rotation.x = lerpf(_leg_l.rotation.x, brace, k)
	_leg_r.rotation.x = lerpf(_leg_r.rotation.x, -brace * 0.55, k)
	_leg_l.rotation.z = lerpf(_leg_l.rotation.z, -brace * 0.9, k)
	_leg_r.rotation.z = lerpf(_leg_r.rotation.z, brace * 0.9, k)
	_knee_l.rotation.x = lerpf(_knee_l.rotation.x, -deg_to_rad(18.0 + 24.0 * t), k)
	_knee_r.rotation.x = lerpf(_knee_r.rotation.x, -deg_to_rad(26.0 + 30.0 * t), k)

	var spread := lerpf(8.0, 68.0, t) if _surfing else lerpf(8.0, 28.0, t)
	# The trailing arm reaches wider than the leading one, which is what a
	# person balancing actually does.
	_arm_r.rotation.z = lerpf(_arm_r.rotation.z, deg_to_rad(spread * (1.0 + 0.3 * _strafe)), k)
	_arm_l.rotation.z = lerpf(_arm_l.rotation.z, -deg_to_rad(spread * (1.0 - 0.3 * _strafe)), k)
	_arm_r.rotation.x = lerpf(_arm_r.rotation.x, sin(_phase) * deg_to_rad(3.0 + 6.0 * t), k)
	_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -sin(_phase) * deg_to_rad(3.0 + 6.0 * t), k)
	_elbow_l.rotation.x = lerpf(_elbow_l.rotation.x, deg_to_rad(-18.0), k)
	_elbow_r.rotation.x = lerpf(_elbow_r.rotation.x, deg_to_rad(-12.0), k)

	# Staff swung back out of the way as the ride gets faster.
	_staff.rotation.x = lerpf(_staff.rotation.x, deg_to_rad(lerpf(-10.0, -78.0, t)), k)

	_torso.rotation.y = lerpf(_torso.rotation.y, deg_to_rad(-14.0 * _strafe), k)
	# Head stays pointed down the line rather than following the shoulders.
	_head.rotation.y = lerpf(_head.rotation.y, deg_to_rad(7.0 * _strafe), k)
	_head.rotation.x = lerpf(_head.rotation.x, deg_to_rad(-6.0 * t), k)


## Cloak and hat trail behind everything else. Both are two-segment, so they
## bend into a curve instead of swinging as one rigid slab.
func _cloak_and_hat(t: float, k: float) -> void:
	var stream := -deg_to_rad(lerpf(7.0, 86.0, t))
	var flap := sin(_phase) * deg_to_rad(3.0 + 9.0 * t)
	_cloak.rotation.x = lerpf(_cloak.rotation.x, stream + flap, k)
	# The lower panel lags the upper one, which is what makes it ripple.
	_cloak_low.rotation.x = lerpf(_cloak_low.rotation.x,
		stream * 0.45 + sin(_phase - 0.9) * deg_to_rad(5.0 + 13.0 * t), k)
	_cloak.rotation.z = lerpf(_cloak.rotation.z, deg_to_rad(-13.0 * _strafe), k)

	_hat.rotation.x = lerpf(_hat.rotation.x,
		-deg_to_rad(lerpf(0.0, 24.0, t)) + sin(_phase * 0.7) * deg_to_rad(2.0 + 4.0 * t), k)
	_hat.rotation.z = lerpf(_hat.rotation.z, deg_to_rad(-8.0 * _strafe), k)
	# The tip whips further than the crown, and later.
	_hat_tip.rotation.x = lerpf(_hat_tip.rotation.x,
		-deg_to_rad(lerpf(0.0, 38.0, t)) + sin(_phase * 0.7 - 1.1) * deg_to_rad(3.0 + 8.0 * t), k)
	_hat_tip.rotation.z = lerpf(_hat_tip.rotation.z, deg_to_rad(-12.0 * _strafe), k)
