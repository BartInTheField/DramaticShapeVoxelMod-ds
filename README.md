# Dramatic Shape Voxel Mod

The overworld as a 3D diorama. Terrain is extruded into real geometry,
occlusion comes from a depth buffer rather than a y-sort, characters stand
as leaning sprite slabs, a shadow map throws real cast shadows across
whatever they land on, and an optional tilt-shift pass sells the
miniature-model look.

Purely presentational. Nothing here reaches collision, movement, triggers
or scripts — it changes what the world *looks* like and nothing about what
it *is*. Battles, menus and cutscenes are untouched; only the free-roam
overworld draws differently.

## Using it

| control | does |
| --- | --- |
| `3`, or the **VOXEL** options row | OFF → 15 → 35 → 50 → 75 → OFF (camera pitch) |
| `5`, or the **V-GRID** options row | OFF / ON — a one-pixel wireframe on every voxel |
| `6`, or the **T-SHIFT** options row | OFF → 1 → 2 → 3 → OFF (miniature blur) |
| `7`, or the **V-CURVE** options row | OFF → 1 → 2 → 3 — bend the world over the horizon |

The four keys sit together, and two of them are taken off the engine: `3`
was **TILT** and `5` was **GBC FX**. Neither is reachable by key while this
mod is enabled, and both are still on the OPTIONS menu. Every key is
free-roam only, and a screen that handles its own keys keeps them, so
nothing here fires while a menu or a text box has focus.

**`3` also turns TILT and GBC FX off**, on every press — including the one
that cycles the ladder back round to OFF. Both fight the diorama: TILT is
the flat fake of what this mode does for real, and GBC FX lays a
full-screen present pass over the top of it. Since `3` is now the only key
that reaches either, it is also the way back from having left one on.

75 degrees is a rung the engine's flat **TILT** could not have: it projects
the world canvas as one rigid plane, which degenerates into a horizon line
down there, where real geometry only gets more of itself to show.

That rung is also the one that gets a **sky**. Pitched that far over the
horizon comes into frame, so the void behind the diorama is filled rather
than left as the black plate it reads as at every rung below — enough to
stand the world under something without a skybox to draw. Outdoors only: a
house, a cave or a gym is a room with a ceiling, and the void past its
walls is the outside of a box, not open air. The colour follows the display
mode like everything else here — blue in the colour modes, grey under
GRAY, green under CLASSIC — and fades in with the camera tween rather than
snapping on at the keypress.

V-CURVE is the *curved world* — every vertex pushed down by the square of
its horizontal distance from the camera's focus, so the ground under you
stays flat and the map bends away over a near horizon. It is not a fisheye:
a fisheye is a lens, a screen-space warp that bends straight lines
everywhere and resamples every pixel to do it. This bends the geometry, so
lines near the camera stay straight and the art stays crisp.

Both pipeline levels persist in `save.options.pipelines`, and V-GRID and
V-CURVE in `save.options.modOptions.DRAMATIC_SHAPE` — the same place the mod
manager's own settings page for this mod reads, so each row is one setting
in two places. VOXEL and the engine's **TILT** are two answers to the same
question, so switching one on switches the other off.

Without shader or depth-canvas support the rows still cycle but the world
stays 2D — the mode reports itself unavailable and the engine keeps the
vanilla path.

## How it is built

This is a *rendering pipeline* mod (see `docs/modding.md`). `main.lua`
registers two records in the engine's `render_pipelines` registry and
writes almost nothing else — the ladder, the options rows, persistence and
the free-roam gate are all engine plumbing driven from those records:

- **`voxel`** — a `drawWorld` pipeline. Replaces the world pass with a
  rendered 3D scene and returns it as one window-resolution canvas.
- **`tiltshift`** — a `worldPresent` pipeline. Post-processes the finished
  world *before* the UI composites, so the diorama blurs and the text boxes
  in front of it stay crisp.

Everything else lives in `lib/`, loaded through the mod's own namespace
(`V.require`) rather than `package.path`, which a mod directory is not on:

| module | role |
| --- | --- |
| `Voxel3D` | the 3D pass: shader, depth buffer, camera, projection |
| `ShadowMap` | the sun's own pass: what it cannot see is in shadow |
| `WorldCurve` | the curved world: the Animal Crossing horizon |
| `VoxelGrid` | the wireframe toggle |
| `ModSetting` | a setting of this mod's own: ladder, store, options row |
| `Mat4` | the 4x4 matrix math the camera and model transforms need |
| `VoxelState` | the camera angle and its ease; the engine owns the level |
| `VoxelScene` | assembles one frame: shadows, terrain, characters, grass |
| `ChunkMesher` | a map's block layer → a terrain mesh, cached per map |
| `Structures` | flood-fills drawn things and decides how tall each is |
| `Buildings` | a profiled building sprite → a voxel model, band by band |
| `TileShape` | resolves every tile to an extrusion class and art mode |
| `TerrainAtlas` | the texture geometry samples: SGB palette bakes, and the animated water/flower tiles |
| `SpriteBillboards` | a sprite frame → a leaning slab with side relief |
| `VoxelModels` | the carved character models in `assets/voxels/` |
| `TiltShift` | the two-pass separable blur and saturation lift |

`data/voxel_heights.lua` is the hand-authored shape profile: listing a tile
there pins its height and art mode over the automatic detector, and its
`buildings` section names whole building sprites to voxelize band by band
(`assets/docs/buidling_to_voxel/` is the pipeline; `assets/docs/buildings/` catalogues the
drawings). Another mod can pin its own tiles by shipping the same file, and
can replace a character's model with `overrides/voxels/<name>.lua` — models
resolve through the engine's asset search path before falling back to ours.

`tools/build_voxels.py` is what carved `assets/voxels/` out of the
overworld sprite sheets. `tools/building_voxels.py` is the reference
implementation of the building voxelizer — it builds the same models
offline, asserts their geometry and renders isometric previews, and its
voxel and shell counts are what `lib/Buildings.lua` is checked against.

## Engine seams it relies on

The mod reaches into a few engine internals (hence `"permissions":
["engine_internals"]`). All but the last are read-only:

- `Game:keypressed` — **wrapped, not read.** The only thing here that
  changes engine behaviour, and the one seam worth arguing about. The
  engine answers its own display keys and returns before a mod's pipeline
  is offered the key, expressly so a pipeline cannot shadow one — so `3`
  (TILT) and `5` (GBC FX) cannot be claimed the documented way, and V-GRID
  and V-CURVE own no render pass and have no registry to claim from at all.
  Only `6` arrives by the supported route. Polling the keyboard instead
  would fire *alongside* the engine's handler rather than instead of it, so
  `3` would cycle both this mode and TILT on one press. The wrapper
  delegates everything it can: `Pipelines.hotkey` still applies its own
  gate and ladder, the settings borrow the voxel pipeline's free-roam gate,
  unclaimed keys pass straight through, and a screen with its own handler
  keeps the keyboard.
- `Player:pose()` / `NPC:pose()` — the sheet, position, facing and step
  phase a frame renders to, so 2D and 3D can never disagree about a pose.
- `SpriteRenderer:resolveImage()` and `SpriteRenderer.STAND/WALK` — the
  live sprite image and frame tables, so palette modes and sprite-replacing
  mods apply to the geometry with no second copy of the logic.
- `TileRenderer.recolorSample` — the exact shade cutoffs the 2D palette
  shader uses, so baked terrain lands on the same colours as flat tiles.
- `TileRenderer.animFrame()` / `.atlasImageData()` / `.defaultAnimatedTiles()`
  — the tile-animation clock, the pixels behind the atlas texture, and the
  vanilla water/flower spec. A static mesh cannot overdraw animated cells
  the way the tile layer does, so it animates the texture instead, and
  these are what let it do that on the engine's own clock and colours.

  Only `defaultAnimatedTiles` is required. The other two are OPTIONAL and
  read guarded, because an engine build is free not to carry them — this
  one does not carry either. Missing `animFrame` freezes the tile clock at
  step 0 (terrain stops animating in voxel mode; everything else is
  unaffected). Missing `atlasImageData` costs nothing where the mod baked
  the atlas itself, falls back to the tileset art where the engine is
  drawing that art unmodified, and skips animating a RED++ per-map bake,
  whose pixels are unreachable without the seam. None of the three may ever
  be called unguarded: a throw inside `drawWorld` costs the player the whole
  pipeline for the session, not one frame of moving water.

## Tests

```sh
luajit mods/DRAMATIC_SHAPE/tests/dramatic_shape_test.lua
```

Runs headless: the mod loads, both pipelines land in the registry with the
shape the engine dispatches on, the ladders and persistence round-trip, and
the whole thing stays inert on a machine with no 3D support.
