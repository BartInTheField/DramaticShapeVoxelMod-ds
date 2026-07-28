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