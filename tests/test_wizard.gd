extends Node
# The rig is authored, so the risk is the script and the scene disagreeing: a
# renamed pivot makes every @onready null and the wizard freezes mid-pose,
# which is easy to miss and impossible to diagnose from a screenshot.

var _main: Node
var _player: SurfPlayer
var _wizard: Node3D
var _failures: Array[String] = []


func _ready() -> void:
	_main = load("res://main.tscn").instantiate()
	add_child(_main)
	_player = _main.get_node("Player")
	_wizard = _player.get_node("Wizard")
	await get_tree().physics_frame

	_check_rig_intact()
	await _check_run_cycle_moves()
	await _check_ride_pose_differs()

	print("")
	if _failures.is_empty():
		print("PASS")
	else:
		for f in _failures:
			print("FAIL: " + f)
	get_tree().quit()


## Every pivot the script poses must exist in the scene.
func _check_rig_intact() -> void:
	var required := [
		"Body", "Body/Torso", "Body/Torso/Head", "Body/Torso/Head/Hat",
		"Body/Torso/Head/Hat/HatTip", "Body/Torso/Cloak", "Body/Torso/Cloak/CloakLow",
		"Body/Hips/LegL", "Body/Hips/LegR", "Body/Hips/LegL/KneeL", "Body/Hips/LegR/KneeR",
		"Body/Torso/ArmL", "Body/Torso/ArmR", "Body/Torso/ArmL/ElbowL",
		"Body/Torso/ArmR/ElbowR", "Body/Torso/ArmR/ElbowR/Staff",
	]
	var missing: Array[String] = []
	for path in required:
		if _wizard.get_node_or_null(path) == null:
			missing.append(path)
	var meshes := _wizard.find_children("*", "MeshInstance3D", true, false).size()
	print("  rig: %d pivots wired, %d meshes, %d missing" % [
		required.size() - missing.size(), meshes, missing.size()])
	if not missing.is_empty():
		_failures.append("rig is missing: %s" % ", ".join(missing))
	if meshes < 18:
		_failures.append("expected a fuller rig, found %d meshes" % meshes)


func _pose() -> Array:
	return [
		(_wizard.get_node("Body/Hips/LegL") as Node3D).rotation.x,
		(_wizard.get_node("Body/Hips/LegL/KneeL") as Node3D).rotation.x,
		(_wizard.get_node("Body/Torso") as Node3D).rotation.y,
		(_wizard.get_node("Body/Torso/Cloak") as Node3D).rotation.x,
	]


## Running must actually cycle -- legs swinging, knees folding.
func _check_run_cycle_moves() -> void:
	var samples: Array = []
	for tick in 90:
		_wizard.set_state(9.0, false, true, 0.0, true)
		await get_tree().process_frame
		if tick % 12 == 0:
			samples.append(_pose())
	var leg_range := 0.0
	var knee_range := 0.0
	var twist_range := 0.0
	for a in samples:
		for b in samples:
			leg_range = maxf(leg_range, absf(a[0] - b[0]))
			knee_range = maxf(knee_range, absf(a[1] - b[1]))
			twist_range = maxf(twist_range, absf(a[2] - b[2]))
	print("  run cycle: hip swing %.0f deg, knee fold %.0f deg, torso twist %.0f deg" % [
		rad_to_deg(leg_range), rad_to_deg(knee_range), rad_to_deg(twist_range)])
	if rad_to_deg(leg_range) < 15.0:
		_failures.append("legs barely swing while running")
	if rad_to_deg(knee_range) < 15.0:
		_failures.append("knees do not fold while running")
	if rad_to_deg(twist_range) < 4.0:
		_failures.append("torso does not counter-rotate while running")


## The riding pose must be a different shape, not the run frozen.
func _check_ride_pose_differs() -> void:
	for tick in 120:
		_wizard.set_state(30.0, true, false, 0.6, false)
		await get_tree().process_frame
	var riding := _pose()
	var cloak := rad_to_deg(riding[3])
	var arm_r := rad_to_deg((_wizard.get_node("Body/Torso/ArmR") as Node3D).rotation.z)
	print("  riding: cloak streamed to %.0f deg, trailing arm out %.0f deg" % [cloak, arm_r])
	if cloak > -40.0:
		_failures.append("cloak does not stream back at speed (%.0f deg)" % cloak)
	if arm_r < 30.0:
		_failures.append("arms do not spread while surfing (%.0f deg)" % arm_r)
