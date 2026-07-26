# Dramatic Shape Voxel Mod

A mod for the [Pokémon Gen 1 Recompilation
Project](https://github.com/bryanthaboi/pokemon-gen1-recomp-project).

The overworld as a 3D diorama. Terrain is extruded into real geometry,
occlusion comes from a depth buffer rather than a y-sort, characters stand
as leaning sprite slabs, a shadow map throws real cast shadows across
whatever they land on, and an optional tilt-shift pass sells the
miniature-model look.

Purely presentational. Nothing here reaches collision, movement, triggers
or scripts — it changes what the world *looks* like and nothing about what
it *is*. Battles, menus and cutscenes are untouched; only the free-roam
overworld draws differently.

## Controls

Every key is free-roam only, and each one is also a row on the OPTIONS
menu.

| control | does |
| --- | --- |
| `3`, or the **VOXEL** options row | OFF → 15 → 35 → 50 → 75 → OFF (camera pitch) |
| `5`, or the **V-GRID** options row | OFF / ON — a one-pixel wireframe on every voxel |
| `6`, or the **T-SHIFT** options row | OFF → 1 → 2 → 3 → OFF (miniature blur) |
| `7`, or the **V-CURVE** options row | OFF → 1 → 2 → 3 — bend the world over the horizon |

Two of those keys are taken off the engine: `3` was **TILT** and `5` was
**GBC FX**. Neither is reachable by key while this mod is enabled, and both
are still on the OPTIONS menu. Pressing `3` also switches both off — they
fight the diorama, and it is the way back from having left one on.