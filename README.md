# Mage Surfers

Source/Quake-style surf movement in Godot 4.5. Prototype: movement feel first,
castle-storming later.

## Run

    ./run.sh          # play
    ./run.sh edit     # open the editor
    ./run.sh test     # headless tests
    ./run.sh bake     # seed levels/ from the tables in tools/maps.gd
    ./run.sh art      # regenerate the castle kit in art/ via headless Blender

This is a Godot **4.5** project (`config_version=5`). `/usr/bin/godot3` is also
installed; opening this project with it rewrites `project.godot` into the Godot 3
format and silently drops the main scene, the input map and the 120 Hz physics
tick, leaving nothing to play.

The desktop integration now points at 4.5, so the menu and double-clicking are
safe: `~/.local/bin/godot4` symlinks the 4.5 binary, `godot4.desktop` is the
default handler for Godot projects, and the Godot 3 menu entry is relabelled
"legacy". To undo, delete `~/.local/share/applications/godot{3,4}.desktop`.

If the config ever gets clobbered again the tells are `config_version=4`, a
`_global_script_classes` block, and a `.import/` folder next to `.godot/`. Check
for a stray editor first -- `pgrep -af godot3` -- because a *running* Godot 3
editor rewrites the file repeatedly, so restoring it while that is open does
nothing.

Controls: **WASD** move · **shift** sprint on foot, air-dash in the air ·
**mouse** look · **LMB** fireball · **RMB** zoom · **E** talk · **G** story/arcade · **L** lobby · **space** jump (hold to bunnyhop) ·
**V** first/third person · **M** next map · **R** last checkpoint · **T** restart
· **esc** cursor

To surf: walk off the start platform onto the ramp, then hold *one* strafe key
and sweep the mouse smoothly in that same direction. Never press W in the air --
it caps your speed.

## Layout

Grouped by feature, each scene next to its script, everything snake_case.

    main.tscn / main.gd     entry point: instances Course, Player and HUD
    blocks/                 reusable level pieces (scene + script each)
    course/                 course.tscn (the level list), level.gd (level root)
    levels/                 the actual levels, one scene each
    player/                 player.tscn, wizard.tscn
    world/                  sky.tres (the Environment, edited in the Inspector)
    ui/                     hud.tscn
    tools/                  authoring-only: layout tables and the baker
    tests/                  headless checks

## Editing levels

Levels are ordinary scenes made of ordinary nodes. Nothing is generated at
runtime.

    ./run.sh edit

then open `levels/01_castle_approach.tscn`. Drag the pieces with the gizmo,
change their properties in the Inspector, save. To add a piece, drag a scene
from `blocks/` in the FileSystem dock straight into the viewport.

| Block | What it is |
|---|---|
| `wave.tscn` | The facing pair of ramps that makes a channel. The piece you place most. `walls`, `gap`, `angle`, `width`, `length`. Origin is mid-channel at the ramps' low edge. |
| `ramp.tscn` | A single wall, when you want one side only. Origin sits on its low edge -- the lip you fall off. |
| `platform.tscn` | A flat pad. Origin is the centre of the top face. |
| `bounce_pad.tscn` | Throws you upward on touch, keeping the speed you arrived with. `launch` in m/s; height is roughly `launch^2 / 40`. |
| `boost_pad.tscn` | Shoves you along the way it points. Rotate to aim -- the push follows its -Z, same as the gizmo's blue arrow. |

| `coin.tscn` | Gold. Bursts out of dead goblins; collected by distance, not overlap, so a pass at speed cannot tunnel through it. |
| `goblin_archer.tscn` | Shoots arrows at you, leading its shots partly. `fire_range`, `fire_interval`, `lead`. Drop it anywhere; it finds the player itself. |

Three more: `finish.tscn` (the wall and gateway; its trigger always fills the
opening), `hazard.tscn` (a volume that sends you to your last checkpoint) and
`checkpoint.tscn` (a `Marker3D` -- put them under the level's `Checkpoints`
node, read in tree order). `decor.tscn` scatters scenery from a seed so it costs
one node rather than a hundred.

### You are not obliged to use any of them

The player collides with **any** static geometry. A plain `CSGBox3D` with
`use_collision` on, rotated past 45 degrees, surfs exactly like a `Ramp` does --
verified, not assumed. So if a block is in your way, drop a CSG box in the level
and drag its handles instead. The blocks only exist to save you repeating the
angle/width arithmetic; they are not a framework you have to build inside.

Levels *instance* these scenes, so editing `blocks/ramp.tscn` changes every ramp
in every level at once.

Each ramp's transform is entirely yours -- move it, yaw it, pitch it. The ramp's
own tilt lives on a generated child, so dragging the node can never put the face
at an angle that stops working. Those generated children are given no `owner`,
so they are rebuilt on load and never bloat the .tscn: a ramp saves as a
transform and a few numbers.

### Adding a level

Duplicate a scene in `levels/`, edit it, then open `course/course.tscn` and drop
it into the **`levels`** array. That array is the play order, and **M** cycles
through it. The root node's `level_name` and `blurb` are what the
HUD shows.

One gotcha: Godot only writes values that *differ* from a script's defaults, so
a ramp left at the default width of 45 stores nothing for it. Changing that
default in `blocks/ramp.gd` therefore moves every ramp still using it. Set the
value on the node if you want it pinned.

### Roughing out a layout from a table

`tools/maps.gd` holds tables and `./run.sh bake` turns each into a level scene --
a way to sketch a long course quickly rather than placing forty ramps by hand.
It refuses to overwrite an existing level; `./run.sh bake --force` regenerates
and **discards any hand editing**. Nothing reads those tables at runtime.

## Running it in the editor

**F5** plays (the main scene is set), **F8** stops.

To tune the feel while playing: with the game running, switch the Scene dock
from *Local* to *Remote*, select Player, and edit the exported values in the
Inspector -- they apply live, so you can feel `air_accel` change mid-ride.
Remote edits are not saved, so copy anything you like back into the defaults in
`player/player.gd`.

Editing `project.godot` by hand while the editor is open will get overwritten
when it saves -- close it first.

## Where the feel lives

`player/player.gd`. Two functions do all the work:

- `_accelerate()` -- Quake's accelerate. Adds speed along your wish direction
  only until your *projection* onto it hits a cap. On the ground the cap is your
  run speed. In the air it is `air_cap` (0.8 m/s), so once you are fast, nearly
  any sideways wish direction is still "under cap" and keeps paying out. That
  loophole is air-strafing.
- `_clip_velocity_to_surfaces()` -- removes the into-the-ramp component of your
  velocity each tick, leaving the along-the-ramp component. Godot will *not* do
  this for you: `move_and_slide()` in grounded mode slides your position along a
  wall but leaves `velocity` untouched, so without this the ramp holds you up
  and you never accelerate.

Dials worth turning, all exported on the Player node:

| Var | Default | Effect |
|---|---|---|
| `air_accel` | 100 | Forgiveness. Surf servers run 100-150; CS:GO is 12. |
| `air_cap` | 0.8 | The surf constant (Source's 30 u/s). Speed gain per tick. |
| `gravity` | 20 | Source's 800 u/s². Higher = faster slide down the ramp. |
| `max_speed` | 7 | Ground run speed only. Does not cap air speed. |
| `friction` | 5 | Ground only. Never applied on ramps or in air. |

## The lobby

`levels/lobby.tscn` is where the game starts, and it is **fully authored** --
every wall, pillar, portal and marker is a real node saved in the scene file.
Nothing about it is generated at runtime. Walls are `CSGBox3D` with
`use_collision` on: one node each, drag the handles to resize, no script.

Layout: a main hall with the vendor on a dais in the north-west corner, a portal
room through the north arch holding the tutorial portals, and the level portals
through the south arch. **L** returns here from anywhere.

- `blocks/portal.tscn` -- drag a level scene into `target_level`, type a
  `label`. Leave the target empty and it says "not built yet" rather than
  silently doing nothing. Two are left unwired deliberately, as slots.
- `blocks/vendor.tscn` -- set `vendor_name` and the `lines` array in the
  Inspector. Walk close, press **E** to step through them.

Play order is the `levels` array on `course/course.tscn`, not filenames.

## The level

**Castle Approach** is level 1 and the default: three short carves broken up by
two flat pads, ending at a castle gateway roughly 330m out. Ride a few seconds,
drop onto a pad, hop off it, ride again. Crossing the gate stops the clock and
shows your time, whether it beat your best, and the top speed you hit. **T**
runs it again, **M** moves on. Best times are per-map and in memory only.

Two bits of layout are load-bearing, both learned the hard way:

- **Each pad butts directly against the start of the next ramp, with no gap.**
  Pads are where you can end up stationary, and a standing jump covers far less
  ground than a ride does. A gap there strands anyone who stops, permanently, at
  that checkpoint. Every gap is on the ramp-to-pad side instead, where you
  arrive falling and the pad is a wide target underneath you.
- **Alternating single walls must run left, right, left.** Riding a left wall
  slides you rightwards, so the next thing to catch has to be the right wall.
  Level 1 currently uses "both" walls throughout, but the Novice map alternates
  and the ordering is not arbitrary -- get it backwards and the ramp throws you
  away from the one you are meant to land on.

The finish is a wall spanning the channel with a gateway through it, and the
trigger fills exactly that opening -- so clearing the level means flying through
the gate, and a gate-sized trigger is honest because the wall is the only other
way past. The opening is as wide as the channel plus a margin, and the wall sits
close behind the last segment: riders leave a ramp still carrying sideways
velocity and drift outward all the way to the wall, so a long run-out lets even
a good line wander into stone. The opening runs from the pad floor upward, so a
rider who fell short can walk in.

## Third person and the wizard

**V** toggles; third person is the default. The player tilts the whole model
onto the ramp face (`model_bank`) and leans it into the strafe (`model_lean`) --
without that, standing bolt upright on a 52° wall reads as stuck to it rather
than carving. First person is still the more precise way to ride.

`player/wizard.tscn` is an authored rig -- every mesh, pivot and material is an
ordinary node you can select, retexture or swap. `wizard.gd` only poses it; it
builds nothing. The script deliberately does **not** animate in the editor,
because posing real saved nodes there would bake whatever frame you saved on.

It animates procedurally rather than playing baked clips, because every pose is
a function of live state: the cloak and hat streaming and fluttering faster the
quicker you go, arms tucked when idle and thrown wide to balance while a ramp is
holding you, the staff swung back out of the way at speed. A canned loop cannot
know any of that, so it reads as a puppet sliding around.

On the ground it runs properly: hips swing, **knees fold on the back half of the
stride** (a straight leg swinging backwards reads as a mannequin being dragged),
the shoulders twist against the hips and the head holds its line against the
shoulders. That last pair is cheap and is most of what makes a run look like a
run. Stride length is fixed so the cycle speeds up with you rather than the feet
skating. Landing squashes the body briefly. In the air the legs stop cycling and
brace instead.

Cloak and hat are both two-segment, and the lower half lags the upper, so they
bend into a curve rather than swinging as one rigid slab.

`ui/speed_lines.tscn` draws radial streaks rushing outward past about 18 m/s,
mostly while airborne. Surf has no other cue for speed once the scenery is far
away -- FOV widens, but the world can be empty for hundreds of metres, so 800
and 2500 u/s otherwise look nearly identical.

## Tests

Headless, no window needed:

    ./run.sh test

- `test_combat` checks goblins fire, arrows cost speed, fireballs aim and kill,
  coins drop and get collected at speed, firing works *while surfing*, and a
  shot carries 300m. Each of these fails silently otherwise -- an archer that
  never shoots looks exactly like one out of range, and a fireball that dies on
  spawn looks exactly like a missed shot.
- `test_wizard` checks every pivot the animation script poses still exists in
  the rig, and that the run cycle and riding pose are genuinely different
  shapes. A renamed pivot otherwise leaves the wizard frozen mid-pose, which is
  impossible to diagnose from a screenshot.
- `test_lobby` checks the lobby loads first, the spawn is solid ground, the
  portals are wired, the vendor talks, and walking into a portal travels.
- `test_blocks` loads every block scene, checks it builds, and checks the pads
  actually move the player. A pad that silently does nothing looks exactly like
  one you placed slightly wrong, which is miserable to debug in the editor.
- `test_level` checks Level 1 structurally: every checkpoint must catch a player
  who simply falls from it, and the gate must fire when crossed. It is
  deliberately not a surf AI -- a bot good enough to play a platforming level is
  its own project, and when it fails you cannot tell whether the level or the
  bot is at fault. That ambiguity hid a reversed zigzag here for several runs.
- `test_surf` drives the whole loop (spawn, walk off, ride) on Novice; ~1100 u/s.
- `test_climb` checks the invariant that makes the game playable: strafing
  up-slope must hold or gain altitude, or every segment is an inevitable slide
  into the gap. y should rise slowly while vz stays at 30.
- `test_speed` rides Velocity with an optimal-strafe bot; ~2900 u/s.

Tests pick maps with `SurfCourse.index_of("name")`, never a bare index -- adding
a map shifts every index after it, and an index-based test goes on passing while
silently measuring the wrong course. They also respawn *after* rebuilding, since
the scene spawns the player on the default map first.

The bots are worth understanding before trusting them. A bot holding a fixed
yaw sits exactly perpendicular to its own velocity, where the strafe only
cancels gravity and speed pins to a constant -- that looks like a broken map but
is a broken bot. `test_speed` instead re-aims every tick to sit just inside
`velocity.dot(wish_dir) < air_cap`, which is the window a human is hunting with
the mouse, and it narrows as 1/v. That is why surf gets harder the faster you go.

## Not done yet

Wizard is primitives (`player/wizard.gd`), swap freely -- the collider is a
plain capsule and nothing depends on the art. No sound, no goal state, no
castle.
# DungeonSurfer
