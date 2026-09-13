extends CharacterBody3D
class_name SurfPlayer

## Emitted when the player runs out of level: a long fall, or a hazard volume.
## The player does NOT decide what happens next -- in story mode that is a
## respawn, in arcade mode it ends the run -- so the rule lives in main.gd.
signal fell

## Quake/Source-style movement controller tuned for surfing.
##
## The whole feel comes from one idea: acceleration is applied along the wish
## direction, but only up to the point where your velocity's *projection* onto
## that direction reaches a cap. On the ground the cap is your run speed, so you
## can never exceed it. In the air the cap is tiny (~0.8 m/s), so once you are
## moving fast, almost any sideways wish direction is still "under cap" and you
## keep gaining speed. That is air-strafing, and surfing is air-strafing while a
## steep ramp holds you up against gravity.

@export_group("Ground")
## Top speed while running on a floor (m/s).
@export var max_speed := 7.0
## Top speed on a floor with sprint held. Ground speed barely matters once you
## are surfing -- this is for crossing pads and lining up the next drop-in.
@export var sprint_speed := 11.5
## How hard you reach max_speed. Source sv_accelerate.
@export var ground_accel := 10.0
## Source sv_friction. Only applied on floors, never on ramps or in air.
@export var friction := 5.0
## Below this speed friction bites at a constant rate. Source sv_stopspeed.
@export var stop_speed := 2.5

@export_group("Air / Surf")
## Source sv_airaccelerate. Surf servers run 100-150; CS:GO deathmatch is 12.
## Higher = more forgiving, you gain speed with sloppier mouse movement.
@export var air_accel := 100.0
## THE surf number. Source air_speed_cap = 30 u/s. Lower it and strafing gives
## less per-tick gain; raise it and you accelerate absurdly fast.
@export var air_cap := 0.8
## Source sv_gravity 800 u/s^2.
@export var gravity := 20.0
## Source jump impulse, ~302 u/s.
@export var jump_force := 7.6
## Hold space to keep hopping (classic bhop). Feels better than tapping.
@export var auto_bhop := true

@export_group("Air dash")
## Shift in the air. Rather than *adding* speed, it brings your speed along the
## dash direction *up to* this value -- the same clamp `_accelerate` uses. So it
## rescues a bad line or crosses a gap when you are slow, and does nothing at
## all when you are already fast. Without that clamp a dash refreshed every
## segment would be a free speed farm and the whole surf economy collapses.
@export var dash_speed := 16.0
## One dash per trip through the air, restored on touching anything.
@export var dash_cooldown := 0.3

@export_group("Scoring")
## Gold multiplier ceiling, and the speed (m/s) each step costs. Killing while
## fast pays more, which is the whole point: without it, stopping to shoot is
## strictly better than shooting on the move, and combat fights the surfing
## instead of feeding it.
@export var max_multiplier := 5
@export var multiplier_step := 12.0

@export_group("Camera")
@export var mouse_sensitivity := 0.0022
@export var base_fov := 78.0
## Extra FOV at fov_max_speed. Big part of "feeling fast".
@export var fov_gain := 28.0
@export var fov_max_speed := 45.0
## Camera roll when strafing, degrees.
@export var strafe_roll := 2.2
@export var third_person_distance := 6.0

@export_group("Combat")
## Right mouse. Narrows the view for aiming and slows the mouse to match, so
## the same hand movement covers fewer degrees.
@export var zoom_fov := 42.0
@export var zoom_sensitivity := 0.45
@export var fireball_cooldown := 0.45
## How far ahead to look for what the crosshair is covering.
@export var aim_distance := 900.0
@export var start_in_third_person := true
## How far the wizard tilts onto the ramp face, 0 = stays upright, 1 = lies flat
## against it. Around two thirds reads as carving without looking broken.
@export var model_bank := 0.65
## Extra lean into the strafe, degrees.
@export var model_lean := 16.0

@export_group("World")
## Facing applied on respawn. The course runs toward +Z and Godot's forward is
## -Z, so a fresh spawn needs turning around or you walk off the back.
@export var spawn_yaw := PI
## Respawn after this long touching nothing at all. Measured as airtime rather
## than depth below a checkpoint, because a pitched segment legitimately drops
## you hundreds of metres below where you entered it -- a depth test would fire
## mid-ride. Any real gap is crossed in well under a second.
@export var fall_timeout := 2.5

var course: Node = null

var _pitch := 0.0
var _checkpoint := 0
var _third_person := false
var _spawn := Vector3(0, 5, 0)
var _best_speed := 0.0
var _surface_normal := Vector3.ZERO
var _air_time := 0.0
var _dash_ready := true
var _dash_timer := 0.0
var _dash_fx := 0.0
var _fire_timer := 0.0
var _zooming := false
## Tracked ourselves rather than read back from Input.mouse_mode: the display
## server does not always grant capture (headless, some window managers), and
## gating the attack on it then silently disables shooting altogether.
var _mouse_free := false
var _hit_fx := 0.0
var _coins := 0
var _kills := 0
var _run_start_z := 0.0
var _distance := 0.0

@onready var _cam_pivot: Node3D = $CamPivot
@onready var _spring: SpringArm3D = $CamPivot/SpringArm3D
@onready var _camera: Camera3D = $CamPivot/SpringArm3D/Camera3D
@onready var _model: Node3D = $Wizard


const FIREBALL := preload("res://player/fireball.tscn")


func _ready() -> void:
	# Goblins find the player through this group.
	add_to_group("player")
	# A ramp only surfs if the engine refuses to treat it as standable ground.
	# Source's limit is normal.y >= 0.7 (~45.6 deg); ours is 45, and the course
	# builds ramps steeper than that so they always slide.
	floor_max_angle = deg_to_rad(45.0)
	floor_snap_length = 0.2
	floor_stop_on_slope = true
	floor_constant_speed = false
	# Critical for surf: let the body slide *along* steep slopes instead of
	# being stopped dead by them.
	floor_block_on_wall = false
	slide_on_ceiling = true
	wall_min_slide_angle = deg_to_rad(5.0)

	_spring.add_excluded_object(get_rid())
	_camera.fov = base_fov
	_camera.far = 6000.0
	_set_third_person(start_in_third_person)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens := mouse_sensitivity * (zoom_sensitivity if _zooming else 1.0)
		rotate_y(-event.relative.x * sens)
		_pitch = clampf(_pitch - event.relative.y * sens, -1.55, 1.55)
		_cam_pivot.rotation.x = _pitch
	elif event.is_action_pressed("ui_cancel"):
		_mouse_free = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and _mouse_free:
		# Only recapture. Otherwise the click that grabs the cursor back would
		# also throw a fireball.
		_mouse_free = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("toggle_view"):
		_set_third_person(not _third_person)
	elif event.is_action_pressed("respawn"):
		respawn(_checkpoint)
	elif event.is_action_pressed("restart_course"):
		respawn(0)


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Wish direction is in world space, derived from where you are looking.
	var wish_dir := (global_basis * Vector3(input.x, 0.0, input.y))
	wish_dir.y = 0.0
	wish_dir = wish_dir.normalized()

	if is_on_floor():
		_apply_friction(delta)
		var ground_top := sprint_speed if Input.is_action_pressed("sprint") else max_speed
		_accelerate(wish_dir, ground_top, ground_accel, delta)
		var jump_pressed := (
			Input.is_action_pressed("jump") if auto_bhop
			else Input.is_action_just_pressed("jump")
		)
		if jump_pressed:
			velocity.y = jump_force
	else:
		# No friction in the air. This is why speed is preserved across gaps.
		_accelerate(wish_dir, air_cap, air_accel, delta)
		velocity.y -= gravity * delta
		if Input.is_action_just_pressed("sprint"):
			_try_dash(wish_dir)

	move_and_slide()
	_clip_velocity_to_surfaces()

	_distance = maxf(_distance, global_position.z - _run_start_z)
	_update_progress()
	_update_camera(input.x, delta)
	_model.set_state(get_horizontal_speed(), is_surfing(), is_on_floor(), input.x,
		Vector2(input.x, input.y).length() > 0.1)
	_update_model(input.x, delta)

	_zooming = Input.is_action_pressed("zoom")
	_fire_timer = maxf(_fire_timer - delta, 0.0)
	if Input.is_action_pressed("attack") and _fire_timer <= 0.0 and not _mouse_free:
		_shoot_fireball()
	_dash_timer = maxf(_dash_timer - delta, 0.0)
	_dash_fx = maxf(_dash_fx - delta * 2.5, 0.0)
	_hit_fx = maxf(_hit_fx - delta * 1.6, 0.0)
	if is_on_floor() or is_on_wall():
		_air_time = 0.0
		_dash_ready = true
	else:
		_air_time += delta
		if _air_time > fall_timeout:
			fell.emit()


## Shift in the air. Dashes along your movement input, or straight ahead if you
## are not holding anything.
func _try_dash(wish_dir: Vector3) -> void:
	if not _dash_ready or _dash_timer > 0.0:
		return
	var dir := wish_dir
	if dir == Vector3.ZERO:
		dir = -global_basis.z
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		return
	dir = dir.normalized()

	var current := velocity.dot(dir)
	if current < dash_speed:
		velocity += dir * (dash_speed - current)
	_dash_ready = false
	_dash_timer = dash_cooldown
	_dash_fx = 1.0


## Redirect velocity along every surface we touched this tick.
##
## This is the single most important function for surf feel, and Godot will not
## do it for you: in MOTION_MODE_GROUNDED, move_and_slide() slides the body's
## *position* along a wall but deliberately leaves `velocity` alone, so running
## into a wall does not steer you. That is right for a corridor shooter and
## fatal for surf -- without this the ramp holds you up but you never accelerate
## along it, you just hang there falling at gravity speed.
##
## Source's TryPlayerMove does the same thing (ClipVelocity against each plane
## it hits). Removing only the into-the-surface component leaves the along-the
## surface component untouched, so gravity's pull down the slope accumulates
## tick after tick -- that accumulation *is* your speed.
func _clip_velocity_to_surfaces() -> void:
	_surface_normal = Vector3.ZERO
	for i in get_slide_collision_count():
		var normal := get_slide_collision(i).get_normal()
		# Remember the ramp we are riding so the model can bank onto it.
		if _surface_normal == Vector3.ZERO and normal.y < cos(floor_max_angle):
			_surface_normal = normal
		if velocity.dot(normal) < 0.0:
			velocity = velocity.slide(normal)


## Quake's classic accelerate(). Only closes the gap between your current speed
## *along wish_dir* and the cap, so it can never push you past the cap in that
## direction -- but it says nothing about your total speed, which is exactly the
## loophole that air-strafing exploits.
func _accelerate(wish_dir: Vector3, wish_speed: float, accel: float, delta: float) -> void:
	if wish_dir == Vector3.ZERO:
		return
	var current := velocity.dot(wish_dir)
	var add_speed := wish_speed - current
	if add_speed <= 0.0:
		return
	velocity += wish_dir * minf(accel * wish_speed * delta, add_speed)


## Source's friction curve: linear in speed, but with a floor so you actually
## come to a stop instead of asymptoting.
func _apply_friction(delta: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed := flat.length()
	if speed < 0.1:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var drop := maxf(speed, stop_speed) * friction * delta
	var scale := maxf(speed - drop, 0.0) / speed
	velocity.x *= scale
	velocity.z *= scale


func _update_camera(strafe_input: float, delta: float) -> void:
	var speed := get_horizontal_speed()
	_best_speed = maxf(_best_speed, speed)
	var t := clampf(speed / fov_max_speed, 0.0, 1.0)
	# The dash punches the FOV out briefly, so it reads even when it added no
	# speed (which, by design, is most of the time).
	var target_fov := base_fov + fov_gain * t + 9.0 * _dash_fx
	if _zooming:
		target_fov = zoom_fov
	# Snappier into the zoom than the speed-driven drift, or aiming feels soupy.
	var rate := 14.0 if _zooming else 6.0
	_camera.fov = lerpf(_camera.fov, target_fov, 1.0 - exp(-rate * delta))
	var target_roll := deg_to_rad(-strafe_roll * strafe_input)
	_camera.rotation.z = lerpf(_camera.rotation.z, target_roll, 1.0 - exp(-8.0 * delta))


## Lays the wizard over onto the ramp face and leans them into the turn.
##
## Standing bolt upright while skating a 50-degree wall looks wrong from behind,
## and this is the whole reason third person is worth having: the tilt is what
## makes the ramp read as a surface you are carving rather than one you are
## stuck to.
func _update_model(strafe_input: float, delta: float) -> void:
	if not _third_person:
		return

	var up := Vector3.UP
	if is_surfing() and _surface_normal != Vector3.ZERO:
		up = Vector3.UP.lerp(_surface_normal, model_bank).normalized()

	# Face the way we are actually travelling, not the way the mouse points.
	var fwd := Vector3(velocity.x, 0.0, velocity.z)
	if fwd.length_squared() < 1.0:
		fwd = -global_basis.z
	fwd = fwd.normalized()

	var right := fwd.cross(up)
	if right.length_squared() < 0.001:
		return
	right = right.normalized()
	fwd = up.cross(right).normalized()

	var target := Basis(right, up, -fwd).rotated(fwd, deg_to_rad(model_lean * strafe_input))
	var current := _model.global_transform.basis.get_rotation_quaternion()
	var blended := current.slerp(target.get_rotation_quaternion(), 1.0 - exp(-9.0 * delta))
	_model.global_transform = Transform3D(Basis(blended), global_position)


func _update_progress() -> void:
	# Only bank progress while actually riding something -- otherwise a long
	# fall past a segment would "unlock" a checkpoint you never reached.
	if course == null or not (is_on_floor() or is_surfing()):
		return
	var points: Array = course.checkpoints
	for i in range(points.size() - 1, -1, -1):
		if global_position.z > (points[i] as Vector3).z - 5.0:
			_checkpoint = i
			return


func _set_third_person(on: bool) -> void:
	_third_person = on
	_spring.spring_length = third_person_distance if on else 0.0
	_model.visible = on
	if not on:
		# Leave the model upright so it is not stuck mid-bank when we return.
		_model.transform = Transform3D.IDENTITY


func respawn(index: int) -> void:
	_checkpoint = index
	if course != null and index < course.checkpoints.size():
		_spawn = course.checkpoints[index]
	global_position = _spawn
	velocity = Vector3.ZERO
	_air_time = 0.0
	_dash_ready = true
	_dash_timer = 0.0
	rotation.y = spawn_yaw
	_pitch = 0.0
	_cam_pivot.rotation.x = 0.0


func is_surfing() -> bool:
	return is_on_wall() and not is_on_floor()


## Normal of the ramp currently being ridden, or zero when not surfing.
func get_surface_normal() -> Vector3:
	return _surface_normal


## Throw a fireball at whatever the crosshair is covering.
##
## The obvious version -- spawn at the camera, fly along the camera's forward --
## is wrong in third person. The camera sits several metres behind the wizard, so
## the fireball appeared behind you and travelled *parallel* to your aim rather
## than converging on it: it always passed beside what the crosshair was on.
##
## Instead: raycast from the camera through the screen centre to find the point
## you are actually pointing at, then throw from the wizard toward that point.
## Correct in both views, and the fireball comes out of the mage.
func _shoot_fireball() -> void:
	_fire_timer = fireball_cooldown

	var cam := _camera.global_position
	var look := -_camera.global_basis.z
	var eye := _cam_pivot.global_position
	# Start the aim ray level with the wizard rather than at the camera, but
	# still on the camera's centre line. In third person the camera sits metres
	# behind you, and a ray from there happily hits the ramp between camera and
	# player -- aiming you at your own feet.
	var start := cam + look * cam.distance_to(eye)
	var target := start + look * aim_distance

	var query := PhysicsRayQueryParameters3D.create(start, target)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.has("position"):
		target = hit["position"]

	# Out of the wizard, not out of the camera.
	var muzzle := eye
	var to_target := target - muzzle
	if to_target.length_squared() < 1.0:
		to_target = look
		target = muzzle + look * aim_distance
	muzzle += to_target.normalized() * 1.2

	var ball: Area3D = FIREBALL.instantiate()
	var host := get_tree().current_scene
	if host == null:
		host = get_tree().root
	host.add_child(ball)
	ball.global_position = muzzle
	ball.look_at(target, Vector3.UP)


## Taken an arrow: lose a slice of speed.
##
## Speed is the resource the whole game runs on -- lose enough and you slide off
## the ramp by yourself -- so draining it is punishment and threat at once, and
## it never yanks control away the way a stun or a knockback would.
func take_hit(fraction: float) -> void:
	velocity.x *= 1.0 - fraction
	velocity.z *= 1.0 - fraction
	_hit_fx = 1.0


## Gold multiplier at the current speed, 1 upward.
func get_multiplier() -> int:
	return clampi(1 + int(get_horizontal_speed() / multiplier_step), 1, max_multiplier)


## Furthest point down the course reached this run, in metres.
func get_distance() -> float:
	return _distance


## A hazard volume, or anything else that should end the attempt.
func perish() -> void:
	fell.emit()


func collect_coin(value: int) -> void:
	_coins += value


func add_kill() -> void:
	_kills += 1


func get_coins() -> int:
	return _coins


func get_kills() -> int:
	return _kills


## Cleared at the start of a run, not on a checkpoint respawn -- dying to a
## goblin should cost you progress, not your whole purse.
func reset_score() -> void:
	_coins = 0
	_kills = 0
	_distance = 0.0
	_run_start_z = global_position.z


## 0 just after firing, 1 when the next fireball is ready. Drives the crosshair.
func get_fire_ready() -> float:
	if fireball_cooldown <= 0.0:
		return 1.0
	return clampf(1.0 - _fire_timer / fireball_cooldown, 0.0, 1.0)


func is_zooming() -> bool:
	return _zooming


## 1 right after being hit, decaying to 0. For UI feedback.
func get_hit_fx() -> float:
	return _hit_fx


## 1 right after a dash, decaying to 0. For camera and UI feedback.
func get_dash_fx() -> float:
	return _dash_fx


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func get_best_speed() -> float:
	return _best_speed


func get_checkpoint() -> int:
	return _checkpoint
