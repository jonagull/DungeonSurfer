# Blender sources

`.blend` files live here, **outside** anything Godot scans. The `.gdignore`
file makes Godot skip this folder entirely -- without it Godot finds the
`.blend` files, tries to import them through Blender itself, and hangs the
editor scan.

    blender/castle_kit.blend        reusable props
    blender/levels/*.blend          one file per level
    art/*.glb                       exports Godot actually reads
    art/levels/*.glb                exported levels

## The rules that matter

**Name anything surfable or solid `Something-col`.** Godot's glTF importer
builds a static collision body from any mesh whose name ends in `-col`.
Meshes without the suffix import as visuals with no collision at all. That one
suffix is the entire physics step -- there is nothing to "lay over it"
afterwards.

  * `-col`      visual mesh **and** collision  (use this for ramps and walls)
  * `-colonly`  collision only, mesh not rendered (invisible blockers)
  * `-convcol`  convex collision, cheaper, only for convex shapes

**Axes.** Blender is Z-up, Godot is Y-up. The exporter maps:

    Blender X  ->  Godot  X
    Blender Z  ->  Godot  Y      (up)
    Blender +Y ->  Godot -Z      (forward)

So build a course running along Blender's **-Y** and it runs along Godot's +Z,
which is the direction every level here already travels.

**Ramp angles survive the trip exactly.** A box rolled 50 degrees in Blender
arrives with a surface normal of (0.77, 0.64, 0) in Godot -- that is cos(50).
Verified, not assumed. But it must stay **above 45 degrees**, or Godot treats
the face as standable floor and you walk up it instead of surfing. Type the
rotation in the N panel; do not eyeball it.

**Scale.** 1 Blender unit = 1 metre = 1 Godot unit. The wizard is 1.8m, and
there is a magenta 1.8m cylinder in `castle_kit.blend` for reference. A Level 1
wave is ~74m wide and ~35m tall, so props sized for a human read as doll
furniture next to one.

## Making a level

1. Copy `levels/example_level.blend` to `levels/<yourname>.blend`.
2. Build it. Surfable surfaces get the `-col` suffix; decoration does not.
3. File > Link to pull props in from `castle_kit.blend`. Linked props update
   everywhere when you fix the original; appended ones are copies.
4. File > Export > glTF 2.0 to `art/levels/<yourname>.glb`.
5. In Godot, drag that `.glb` into a level scene. Collision is already there.
6. Add the gameplay objects in Godot: checkpoints, `finish.tscn`, goblins,
   portals. Those cannot come from Blender.
