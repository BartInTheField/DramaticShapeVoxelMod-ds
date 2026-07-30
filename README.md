# Dramatic Shape Voxel Mod

A mod for the [Pokémon Gen 1 Recompilation
Project](https://github.com/bryanthaboi/pokemon-gen1-recomp-project).

The overworld as a 3D diorama. Terrain is extruded into real geometry,
occlusion comes from a depth buffer rather than a y-sort, characters stand
as leaning sprite slabs, a shadow map throws real cast shadows across
whatever they land on, and an optional tilt-shift pass sells the
miniature-model look.

And battles fought on that world rather than on a white field. When
something picks a fight the map's NPCs are culled, the engine's own wipe
plays over the empty map, and the battle draws over the nearest patch of
clear ground — shot over the shoulder, the player's mon low and left and
the enemy high and right, with a slow parallax drift behind them and a
depth-of-field pass that keeps both of them sharp.

Purely presentational. Nothing here reaches collision, movement, triggers
or scripts — it changes what the world *looks* like and nothing about what
it *is*. The battle arena is where the **camera** goes, not where anybody
goes: no cell, facing, flag or warp is written, so the player is standing
exactly where the fight found them when it ends.

## Controls

Every key is free-roam only, and each one is also a row on the OPTIONS
menu.

| control | does |
| --- | --- |
| `3`, or the **VOXEL** options row | OFF → 15 → 35 → 50 → 75 → OFF (camera pitch) |
| `5`, or the **V-GRID** options row | OFF / ON — a one-pixel wireframe on every voxel |
| `6`, or the **T-SHIFT** options row | OFF → 1 → 2 → 3 → OFF (miniature blur) |
| `7`, or the **V-CURVE** options row | OFF → 1 → 2 → 3 — bend the world over the horizon |
| `8`, or the **3D-BTL** options row | ON / OFF — fight on the map instead of on a white field |
| the **DAYTIME** options row | DAY / NIGHT / DUSK / DAWN / SYNC / CYCLE — what time it is outdoors |

**3D-BTL** is on by default and is independent of **VOXEL**: battles draw
on the world whether or not the free-roam camera is pitched over.

The void behind the diorama is a **gradient sky** at every **VOXEL** rung:
four blues as flat horizontal bands, deepest overhead and palest at the
bottom, with a checkerboard of the next band dithered into the bottom of each
one — the 8-bit way to get more colours out of a palette than it holds. Every
channel is a multiple of 8, where a five-bit GBC channel lands. No clouds, and
no image asset.

At `75` the camera is pitched far enough over that the ground plane's vanishing
line is in frame, and the pale end meets it; at the steeper rungs that line is
above the top edge, so the bands take a fixed slice of the frame and the haze
below them fills the void where the ground runs out. Nothing is resampled —
no baked 160×144 picture scaled up, no texture at all, just one rectangle
through a shader that answers each pixel from its own coordinate — and the
band edges and dither cells are measured in the diorama's own pixels, handed
in every frame, so a `ZOOM` change lands immediately and stays crisp at any
window size. The palette goes through the display-mode transform like
everything else here, so GRAY gets four greys and CLASSIC four greens.
Overworld only — a battle's placed camera looks up from under the horizon and
keeps its flat sky.

Tunables live at the top of `lib/Sky.lua` — `Sky.DITHER`, `Sky.DITHER_START`
(how far down each band the checker begins — lower is a wider blend, `1`
switches it off), `Sky.SPAN` (how much of the frame the bands cover on the
rungs whose horizon is off-screen), and `Sky.DISC_FRAC` (the sun and moon's
size, as a fraction of the frame) — and the palettes live in `lib/DayNight.lua`
(`DayNight.PALETTES`, one per phase, lightest first), because the sky belongs
to the clock:

## What time it is

The **DAYTIME** row is one twenty-minute clock — ten minutes of sun, ten of
moon. `DAY`, `NIGHT`, `DUSK` and `DAWN` are pins on that dial (noon,
mid-night, sunset, sunrise), `CYCLE` lets it run, picking up from whichever
pin (or SYNC sky) was showing, and `SYNC` — the default — lays your
machine's own clock onto the dial: local noon is the DAY pin, midnight is
NIGHT, six and eighteen the twilights, so out of the box Kanto's evening
falls when yours does.
Everything is a pure function of the clock, so the pinned DUSK is exactly
the running cycle stopped at sunset. Setting **VOXEL** to `FULL` switches
DAYTIME to `CYCLE` with the rest of the preset.

The **sun and moon hang in the sky**, projected through the same matrix the
geometry is drawn with, so each stands over the point on the horizon its
shadows point away from at any pitch, window shape or zoom. Noon is this
mod's existing sun to the digit — southeast, 45° up, overhead behind the
north-facing camera and correctly out of frame — and the arc swings north at
both ends, so the disc stands in frame through dawn and dusk, half-set on
the horizon line. The moon walks the northern sky all night, due north at
mid-night. Both are cell art on the sky's own grid, sized by the frame, and
scissored to the sky's region: a setting body slips below the horizon point
and is gone — never under the map.

The **sky, the shadows and the light follow**. Six-band phase palettes
blend along the dial and re-quantise onto the 5-bit lattice — the evening
bending through a golden-hour waypoint and both edges of the night through
a violet civil twilight, because a straight lerp between complements
bottoms out in grey — and a dithered, posterised glow warms the bands
around the low sun through the twilights.
The shadow shear comes off the clock (opposite the body's bearing,
cotangent-long, clamped at twice the caster's height), fading out over the
last twelve degrees before the horizon so sunset hands off to moonrise
through a soft shadowless gap; moonlight presses at about two-thirds the
sun's weight. The scene shader multiplies every surface by the hour's tint —
neutral at noon, warm at the twilights, dim blue under the moon.

The **windows are glass**. The panes in the overworld art — the framed
squares on building fronts and the small lights in doors — are found by
*shape* in the tileset image itself (a black border row, black-flanked glass
rows, a closing border; no tile ids anywhere), and marked on a mask texture
the scene shader samples alongside the atlas. By day a thin glint crosses
them **while you move** — the sweep is fed by the camera's own travel and
dies within a beat of standing still, because a reflection is something the
viewpoint does — with the art still visible through it. After dark they are
**lit from inside**:
the pane's own shine pattern carried into a warm lamp colour, exempt from
the sun, the shadow map and the hour's tint. The lamps come on through dusk,
burn all night, and are mostly out again by dawn.

**Outdoors only.** Indoors keeps the noon rig, the neutral tint and no sky:
a cave at midnight is exactly as dark as a cave at noon. Viridian Forest is
the case between — a **canopy** map: no sky and the light through the
leaves stays at the mod's fixed noon angle, but the hour's *tint* still
falls through, so night reaches the forest floor. A battle staged on
an outdoor map fights under the hour — night void behind the arena, tinted
mons, sunset taking the arena's shadows with it — and an indoor arena is
untouched. The engine's `world.tod` hook is answered
(`MORNING`/`DAY`/`EVENING`/`NIGHT`), so palette or music packs keyed to the
period ride this clock for free. In `CYCLE`, the time is written into the
mod's own bucket in the save file when the game saves, and read back when
the save is opened; a save with no clock in it starts at day.

While a battle can be staged on the map — **3D-BTL** on, or **VOXEL** on
`FULL`, which owns that row — the engine's **BATTLE LAYOUT** row is set to
`OG` and taken off the OPTIONS menu. The staged shot is composed in the Game
Boy's own 160x144 frame: the arena camera is solved to put a cell under each
of the two pics' feet, and `WIDE` re-lays that screen out on a 304x144
surface, which moves every anchor it is solved against. Switching **3D-BTL**
off hands the row straight back with `WIDE` selectable again.

Leaving a battle fades rather than cuts while **VOXEL** is on: the battle
screen fades to black, closes behind it, and the map fades up out of it. The
engine wipes *into* a fight and cut straight out of one, which is a big jump
between the arena's placed camera and the walking diorama. It applies to every
battle while the mode is on — including one that found no arena and drew on
the flat battle screen — and not at all while the mode is off. The timing is a
`voxel_battle_exit` transitions record, so a data pack can retune it.

The two HP boxes snap to the window's own edges while a battle is staged —
the foe's to the left, yours to the right — instead of huddling in the middle
of the frame with map showing either side of them. Same tiles, same size,
same rows, on the same frosted glass; only the pair's position changes. On a
window shaped like the GB screen there is nowhere to snap to and nothing
moves.

## Where a battle is staged

The mod looks for the nearest clearing shaped like this, where every `x` is
a cell the player could walk onto — the two mons three cells apart down the
middle, with a one-cell apron so the camera looks across floor rather than
into a wall:

```
x x x
x O x     O   the enemy's mon
x x x
x x x
x P x     P   your mon
x x x
```

Indoors, in a corridor or in a cave there is often no room for that, so the
search relaxes to the same three-cell gap with the apron given up:

```
O
x
x
P
```

If neither will fit — and on a map with no open ground at all, or on a
machine with no depth-buffer support — the battle draws exactly the way it
always did. Water counts as open ground while you are surfing and not
otherwise, and warp tiles never count, so a fight is never framed in a
doorway.

Two of those keys are taken off the engine: `3` was **TILT** and `5` was
**GBC FX**. Neither is reachable by key while this mod is enabled, and both
are still on the OPTIONS menu. Pressing `3` also switches both off — they
fight the diorama, and it is the way back from having left one on.