@tool
extends Node3D
class_name SurfLevel

## Root of an editable level scene.
##
## Everything a level is made of is an ordinary node you can select and drag:
## SurfRamp, SurfPlatform, SurfFinish, and Marker3D checkpoints under a
## "Checkpoints" child. Reorder, duplicate or delete them freely -- this script
## just reads whatever is there when the level loads.

signal reached_goal

@export var level_name := "Untitled"
@export var blurb := ""

## Filled from the Checkpoints markers, in tree order, when the level loads.
var checkpoints: Array[Vector3] = []


func _ready() -> void:
	collect_checkpoints()
	if Engine.is_editor_hint():
		return
	var finish := find_finish()
	if finish != null:
		finish.crossed.connect(func() -> void: reached_goal.emit())


## Checkpoint positions, in the order the markers appear in the scene tree.
## Drag a marker in the editor and the respawn point moves with it.
func collect_checkpoints() -> void:
	checkpoints.clear()
	var holder := get_node_or_null("Checkpoints")
	if holder == null:
		push_warning("%s has no Checkpoints node" % level_name)
		return
	for child in holder.get_children():
		if child is Marker3D:
			checkpoints.append((child as Marker3D).global_position)


func find_finish() -> SurfFinish:
	for child in get_children():
		if child is SurfFinish:
			return child
	return null
