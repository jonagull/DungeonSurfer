#!/usr/bin/env bash
# Launch with the right engine.
#
# /usr/bin/godot3 is Godot 3 and is what the desktop menu and double-clicking a
# project use. Opening this project with it rewrites project.godot into the
# Godot 3 format and silently drops the main scene, the input map and the
# physics tick rate. Always start from here.
set -euo pipefail

GODOT="${GODOT:-$HOME/.local/bin/godot4}"
[[ -x "$GODOT" ]] || GODOT=/home/boien/Downloads/Godot_v4.5-stable_linux.x86_64
cd "$(dirname "$0")"

if [[ ! -x "$GODOT" ]]; then
	echo "Godot 4 not found at: $GODOT" >&2
	echo "Set GODOT=/path/to/godot4 and re-run." >&2
	exit 1
fi

case "${1:-play}" in
	play) exec "$GODOT" --path . ;;
	edit) exec "$GODOT" --editor --path . ;;
	art)
		# Regenerates the castle kit in art/ from tools/blender/make_kit.py.
		# Headless Blender -- no window, no addon, no MCP.
		command -v blender >/dev/null || { echo "blender not found on PATH" >&2; exit 1; }
		shift || true
		exec blender --background --python tools/blender/make_kit.py -- art/ "$@"
		;;
	bake)
		# Seeds res://levels from the tables in tools/maps.gd. Refuses to
		# overwrite existing level scenes unless you pass --force, which
		# discards any hand editing.
		shift || true
		exec "$GODOT" --headless --path . --script res://tools/bake_levels.gd -- "$@"
		;;
	test)
		for t in tests/test_wizard tests/test_lobby tests/test_blocks tests/test_combat tests/test_modes tests/test_level tests/test_surf tests/test_climb tests/test_speed; do
			echo "--- $t ---"
			"$GODOT" --headless --path . "res://$t.tscn" --quit-after 40000
		done
		;;
	*) echo "usage: $0 [play|edit|test|bake [--force]|art]" >&2; exit 2 ;;
esac
