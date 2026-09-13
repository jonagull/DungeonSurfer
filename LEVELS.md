# Making a good surf level

Numbers here are measured from this game's movement, not general advice. Player
gravity is 20 m/s², run speed 7 (11.5 sprinting), jump 7.6, air dash 16.

## The one rule that is not negotiable

**Ramp faces must be steeper than 45°.** At 45° or shallower the engine treats
the face as standable floor and you walk up it. Blocks default to 50°. Below
about 47° it gets twitchy near the bottom edge; above about 60° you descend so
fast the ramp is gone before you can do anything with it.

## Budgeting speed

There is no air friction, so a ramp has no terminal velocity. Speed is bounded
only by the height you have left to trade:

    top speed ≈ sqrt(2 × 20 × drop)

| Drop | Top speed | In game units |
|---|---|---|
| 30 m | 34 m/s | ~1350 u/s |
| 90 m | 60 m/s | ~2360 u/s |
| 250 m | 100 m/s | ~3900 u/s |
| 500 m | 141 m/s | ~5500 u/s |

So if you want a fast level, the only real lever is **total descent**. A wave
caps you at its own height and runs dry in seconds. To keep speed building past
that, pitch whole sections nose-down so the channel keeps descending as it runs.

Reference: Level 1 peaks around 1200 u/s, Velocity around 2900.

## Budgeting time on a ramp

Gravity pulls you down the slope at `20 × sin(angle)` — about 15 m/s² at 50°.
A skilled rider cancels most of that by strafing up-slope, but a new one does
not. Assume a beginner crosses the full face in **3 to 5 seconds**.

`width` (the face length up the slope) is therefore your difficulty dial, not
`length`. It is how much room there is to be wrong in:

- **45** — a few seconds. Punchy, demands attention. Level 1 uses this.
- **70** — comfortable, room to recover.
- **120** — very forgiving, long rides. Velocity uses this.

## Gaps you can actually cross

Flight time is `gap / speed`, and you fall `10 × t²` metres in that time.

| Gap | At 7 m/s (walking off) | At 25 m/s (riding) |
|---|---|---|
| 6 m | 0.9 s, falls 7 m | 0.2 s, falls 0.6 m |
| 15 m | 2.1 s, falls 44 m | 0.6 s, falls 3.6 m |
| 30 m | 4.3 s, falls 184 m | 1.2 s, falls 14 m |

The walking column is the one that bites. Which leads to:

## Two layout rules learned the hard way

**1. Never leave a gap immediately after a flat pad.**

Pads are where a player can come to a complete stop. A standing jump crosses
almost nothing, and the numbers above show a 15 m gap drops you 44 m if you
leave at walking pace. If the next ramp is not that far below, they cannot make
it — and since they respawn on the pad, they cannot *ever* make it. That is a
permanent softlock at a checkpoint.

Put pads flush against the start of the next ramp. Keep gaps on the
ramp-to-pad side, where players arrive fast and falling and the pad is a wide
target underneath them.

**2. Alternating single walls must go left, right, left.**

Riding a left wall slides you rightwards. So the next thing to catch must be
the right wall. Get this backwards and the ramp throws you away from the very
thing you are meant to land on — it looks like a gap that is slightly too big,
but no amount of skill fixes it.

Use `walls: Both` when you want a forgiving stretch: miss one side and the
other catches you. Single walls are the interesting shape; use them once the
player is warmed up.

## Checkpoints

- Put one at the top of every ramp a player is meant to ride, a few metres
  above the face so they slide on and build speed naturally.
- **Never put one directly over the channel gap.** Dead centre on a pad sits
  above the hole between the next pair of ramps, so respawning and walking
  forward drops you straight through. Offset them to one side.
- Respawns give you zero velocity. Check every checkpoint catches a player who
  simply falls from it — `./run.sh test` does exactly this.

## The finish

Put the gateway **close behind the last section**, within about 25 m. Riders
leave a ramp still carrying sideways velocity and drift outward the whole way
to the wall, so a long run-out lets a good line drift into stone.

Make the opening at least as wide as the channel. Run it from the floor up so a
rider who fell short can walk in.

## A shape that works

Level 1's rhythm, which is a good default:

1. A both-walls wave to open on. A missed line still catches something.
2. A pad. Land, breathe, line up.
3. A wave, dropped a little lower.
4. A pad.
5. A last wave, then the gate right behind it.

Ride a few seconds, break, re-aim, land, ride. A wave you can hold indefinitely
stops asking anything of you after about five seconds.

## Checking your work

    ./run.sh test

`test_level` drops a player from every checkpoint and fails if any of them falls
into nothing. Point it at your level by changing `MAP` in `tests/test_level.gd`.

## Placing goblins

Drop `blocks/goblin_archer.tscn` anywhere with flat footing -- pads and the end
platform are the natural spots. They find the player themselves.

Arrows cost you a slice of **speed**, not health. Speed is the resource the
whole game runs on, so draining it is both the punishment and the threat, and it
never yanks control away the way a stun or a knockback would. Flow survives.

- Put them where the player is already *committed*: mid-flight between waves, or
  on a pad they must cross. An archer you can simply avoid looking at is scenery.
- Face them across the channel rather than down it. A goblin directly ahead is
  shot trivially; one off to the side makes you choose between aiming and
  holding your line.
- `lead` at 0.55 is the sweet spot. At 1.0 they are unavoidable at speed; at 0.0
  they never land a shot. Both are equally boring.
- Six on a level of Level 1's length feels busy already. Start sparse.

Fireballs detonate on terrain as well as goblins, so a goblin standing flush on
a wide pad is hard to hit with a flat shot. Give them a little elevation, or
expect the player to shoot down at them on the way past.
