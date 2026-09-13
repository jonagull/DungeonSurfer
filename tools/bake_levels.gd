extends SceneTree

## Writes each table in maps.gd out as an editable level scene under res://levels.
##
## Run once to seed the scenes; after that the scenes are the source of truth
## and this will refuse to clobber them. Pass --force to regenerate anyway,
## which discards any hand editing.
##
##   godot --headless --path . --script res://tools/bake_levels.gd -- --force

const MAPS := preload("res://tools/maps.gd")
const BUILDER := preload("res://tools/level_builder.gd")
const OUT_DIR := "res://levels"


func _init() -> void:
	var force := "--force" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	for i in MAPS.MAPS.size():
		var map: Dictionary = MAPS.MAPS[i]
		# No numeric prefix. Play order comes from the Course's `levels` array,
		# not the filename -- and a prefix means inserting a map at the top
		# renumbers every file, writing new ones alongside the old rather than
		# skipping them. That silently duplicated every level and came within
		# one command of discarding hand-placed enemies.
		var path := "%s/%s.tscn" % [OUT_DIR, _slug(map["name"])]

		if FileAccess.file_exists(path) and not force:
			print("skip   %s (already exists; --force to overwrite)" % path)
			continue

		var root := BUILDER.build(map)
		_own(root, root)
		var packed := PackedScene.new()
		var err := packed.pack(root)
		if err != OK:
			printerr("pack failed for %s: %d" % [path, err])
			continue
		err = ResourceSaver.save(packed, path)
		if err != OK:
			printerr("save failed for %s: %d" % [path, err])
			continue
		print("wrote  %s  (%d nodes)" % [path, _count(root)])
		root.free()

	quit()


## Every node needs an owner or it is not written into the packed scene.
##
## Instanced sub-scenes are the exception: give the instance an owner so it is
## recorded, but do not recurse into it. Owning its internals would expand the
## instance into loose nodes and sever the link to blocks/ramp.tscn.
func _own(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		if child.scene_file_path.is_empty():
			_own(child, root)


func _count(node: Node) -> int:
	var n := 1
	for child in node.get_children():
		n += _count(child)
	return n


func _slug(name: String) -> String:
	return name.to_lower().replace(" ", "_")
