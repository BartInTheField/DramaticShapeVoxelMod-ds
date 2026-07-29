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

**3D-BTL** is on by default and is independent of **VOXEL**: battles draw
on the world whether or not the free-roam camera is pitched over.

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