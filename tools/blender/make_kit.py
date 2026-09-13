"""Generates a modular castle kit and exports each piece as .glb.

Run headless -- no MCP, no addon, no Blender window:

    blender --background --python tools/blender/make_kit.py -- art/

Every piece is built from parameters, so changing a number and re-running
regenerates the whole kit. Open the .blend-free pieces in Blender any time by
importing the .glb if you want to sculpt them by hand instead.

Conventions that matter for this project:
  * 1 Blender unit = 1 metre = 1 Godot unit. The wizard is 1.8m.
  * Origin sits at the FLOOR of each piece, centred, so dropping one into a
    Godot level puts it on the ground rather than half-buried.
  * Pieces are decoration only. Nothing here is surfable -- the ramps stay
    Godot blocks so their angles remain exact and verifiable.
"""

import bpy
import math
import os
import sys


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.materials):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def material(name, rgb, roughness=0.9, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return mat


def box(name, size, location, mat):
    # primitive_cube_add(size=1.0) is already 1 unit across, so the scale IS
    # the size. Halving it here made every box in the kit half its intended
    # dimensions.
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    obj.data.materials.append(mat)
    return obj


def cylinder(name, radius, depth, location, mat, verts=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth,
                                        location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def join_and_export(name, outdir):
    """Merge everything into one object and write <name>.glb.

    Scale and rotation are baked into the vertices before joining. Otherwise
    the joined object inherits whatever transform the active object happened to
    have, every other piece is counter-scaled to compensate, and the mesh that
    reaches Godot no longer measures what you built.
    """
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    # Origin at the floor, centred, so dropping one into a level puts it on the
    # ground rather than half-buried.
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    # Blender is Z-up, glTF is Y-up; the exporter converts, so build in Z-up.
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(outdir, name + ".glb"),
        export_format="GLB",
        use_selection=False,
    )
    print("wrote %s.glb" % name)


def at(offset, x, y, z):
    return (offset[0] + x, offset[1] + y, offset[2] + z)


def build_pillar(o=(0, 0, 0)):
    stone = material("stone", (0.60, 0.56, 0.50))
    trim = material("trim", (0.42, 0.36, 0.50), roughness=0.75, metallic=0.2)
    box("pillar_base", (2.6, 2.6, 0.5), at(o, 0, 0, 0.25), stone)
    box("pillar_plinth", (2.2, 2.2, 0.4), at(o, 0, 0, 0.65), stone)
    cylinder("pillar_shaft", 0.85, 8.0, at(o, 0, 0, 4.85), stone)
    cylinder("pillar_ring", 0.95, 0.3, at(o, 0, 0, 5.6), trim)
    box("pillar_capital", (2.4, 2.4, 0.7), at(o, 0, 0, 9.2), stone)
    box("pillar_abacus", (2.8, 2.8, 0.35), at(o, 0, 0, 9.7), trim)


def build_arch(o=(0, 0, 0)):
    stone = material("stone", (0.60, 0.56, 0.50))
    for side in (-1, 1):
        box("arch_leg%d" % side, (1.6, 1.6, 9.0), at(o, side * 5.2, 0, 4.5), stone)
        box("arch_foot%d" % side, (2.2, 2.2, 0.6), at(o, side * 5.2, 0, 0.3), stone)
    # Voussoirs stepped round a half circle, which reads as an arch far better
    # than a single curved slab.
    steps = 9
    for i in range(steps):
        angle = math.pi * (i + 0.5) / steps
        piece = box("arch_stone%d" % i, (1.7, 1.6, 1.5),
                    at(o, math.cos(angle) * 5.2, 0, 9.0 + math.sin(angle) * 3.2), stone)
        piece.rotation_euler = (0, -angle + math.pi / 2, 0)
    box("arch_cap", (12.4, 1.8, 0.8), at(o, 0, 0, 12.8), stone)


def build_brazier(o=(0, 0, 0)):
    iron = material("iron", (0.20, 0.19, 0.22), roughness=0.5, metallic=0.7)
    ember = material("ember", (1.0, 0.45, 0.12), roughness=0.4)
    cylinder("brazier_foot", 0.7, 0.2, at(o, 0, 0, 0.1), iron)
    for i in range(3):
        angle = 2 * math.pi * i / 3
        leg = box("brazier_leg%d" % i, (0.16, 0.16, 1.7),
                  at(o, math.cos(angle) * 0.38, math.sin(angle) * 0.38, 0.95), iron)
        leg.rotation_euler = (math.sin(angle) * 0.18, -math.cos(angle) * 0.18, 0)
    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.45, radius2=0.95,
                                    depth=0.8, location=at(o, 0, 0, 2.1))
    bowl = bpy.context.active_object
    bowl.name = "brazier_bowl"
    bowl.data.materials.append(iron)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.6,
                                          location=at(o, 0, 0, 2.5))
    coals = bpy.context.active_object
    coals.name = "brazier_coals"
    coals.scale = (1.0, 1.0, 0.45)
    coals.data.materials.append(ember)


PIECES = [
    ("pillar", build_pillar),
    ("arch", build_arch),
    ("brazier", build_brazier),
]


def reference_wizard(o):
    """A 1.8m stand-in for the player, so nothing gets modelled the wrong size.

    Scale is the single easiest thing to get wrong here, and the most expensive
    to discover after a prop set is finished.
    """
    pale = material("reference", (0.85, 0.3, 0.55), roughness=1.0)
    cylinder("REFERENCE_wizard_1m8", 0.3, 1.8, at(o, 0, 0, 0.9), pale, verts=10)


def make_workbench(outdir, force):
    """Writes art/castle_kit.blend: every piece laid out side by side, unjoined
    and fully editable. This is the file to open in Blender.

    It will not overwrite an existing one without --force, because the whole
    point is that you edit it by hand.
    """
    path = os.path.abspath(os.path.join("blender", "castle_kit.blend"))
    if os.path.exists(path) and not force:
        print("skip   castle_kit.blend (already exists; --force to regenerate)")
        return
    clear_scene()
    spacing = 0.0
    for name, builder in PIECES:
        builder((spacing, 0, 0))
        spacing += 20.0
    reference_wizard((-14.0, 0, 0))
    # compress=True is a 10x saving -- 1.0MB down to 0.10MB for this kit --
    # and matters because .blend is binary, so every commit stores a whole new
    # copy rather than a diff.
    bpy.ops.wm.save_as_mainfile(filepath=path, compress=True)
    print("wrote  castle_kit.blend  (open this one in Blender)")


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    outdir = args[0] if args and not args[0].startswith("--") else "art"
    force = "--force" in args
    os.makedirs(outdir, exist_ok=True)
    os.makedirs("blender", exist_ok=True)
    for name, builder in PIECES:
        clear_scene()
        builder()
        join_and_export(name, outdir)
    make_workbench(outdir, force)
    print("kit written to %s" % outdir)


main()
