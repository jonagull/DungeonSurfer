@tool
extends Node3D
class_name SurfCourse

## Holds the level list and swaps between them.
##
## Levels are plain scenes, listed in the Inspector on this node. Drop a new one
## into the array and it joins the M rotation; reorder the array to reorder the
## game. Nothing is generated at runtime -- the course instances whichever level
## scene is current and reads its checkpoints and finish.

signal reached_goal
## Fired whenever a different level is loaded, including through a portal.
signal level_changed

## Level scenes, in play order. Each root must have level.gd on it.
@export var levels: Array[PackedScene] = []:
	set(value):
		levels = value
		if is_inside_tree():
				build_map(map_index)

## Which level to show in the editor viewport and start the game on.
@export var start_level := 0:
	set(value):
		start_level = value
		if is_inside_tree():
			build_map(value)

var checkpoints: Array[Vector3] = []
var map_index := 0

var _level: SurfLevel = null


func _ready() -> void:
	# Portals find the course through this group.
	add_to_group("course")
	build_map(start_level)


func level_count() -> int:
	return levels.size()


## Look a level up by its display name, so callers never depend on an index --
## inserting a level shifts every index after it, silently.
func index_of(level_name: String) -> int:
	var slug := level_name.to_lower().replace(" ", "_")
	for i in levels.size():
		if levels[i] == null:
			continue
		var file := levels[i].resource_path.get_file()
		if file.trim_suffix(".tscn").trim_suffix(".scn").ends_with(slug):
			return i
	push_error("no level matching: " + level_name)
	return 0


func map_name() -> String:
	return _level.level_name if _level != null else "?"


func map_blurb() -> String:
	return _level.blurb if _level != null else ""


func next_map() -> void:
	if not levels.is_empty():
		build_map((map_index + 1) % levels.size())


func build_map(index: int) -> void:
	if levels.is_empty():
		push_warning("Course has no levels assigned -- drop level scenes into its `levels` array.")
		return
	map_index = clampi(index, 0, levels.size() - 1)
	_instantiate(levels[map_index])


## Load a level scene directly. Used by portals, which hold a scene rather than
## an index so that reordering the `levels` array cannot silently repoint them.
func load_scene(scene: PackedScene) -> void:
	if scene == null:
		return
	var known := levels.find(scene)
	map_index = known if known >= 0 else map_index
	_instantiate(scene)


func _instantiate(scene: PackedScene) -> void:
	# Detach before freeing: queue_free() is deferred, and leaving the old level
	# colliding for a frame would drop the player through the new one.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_level = null
	checkpoints.clear()

	var instance := scene.instantiate()
	add_child(instance)
	if instance is SurfLevel:
		_level = instance
		checkpoints = _level.checkpoints.duplicate()
		if not Engine.is_editor_hint():
			_level.reached_goal.connect(func() -> void: reached_goal.emit())
	else:
		push_error("level root is not a SurfLevel: " + scene.resource_path)
	level_changed.emit()
