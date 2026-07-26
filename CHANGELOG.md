# Changelog

## Unreleased

Real shadows. The sun moves to the southeast and drops to 45 degrees, so
shadows fall northwest -- up and to the left on screen -- and run about as
long as the thing throwing them is tall.

### Added

- `lib/ShadowMap.lua`: the scene rendered once from the sun into an
  orthographic depth map, which the main pass then samples per fragment.
  What the sun cannot see is in shadow, whatever surface it is, so a
  shadow climbs a wall, drapes over a roof and slides across a passing
  NPC with no case in the code -- and every caster is simply whatever the
  pass draws. The terrain mesh goes in, which means buildings, trees,
  ledges, signs and every prop cast, where before only characters did.
- Depth is packed into two 8-bit channels of an ordinary color canvas
  (~16 bits over a ~700px frustum, a hundredth of a world pixel).
  Readable depth textures are the least portable corner of the graphics
  API, and the mod's contract is that an unsupported driver falls back
  rather than errors: `available()` reports, and VoxelScene keeps the old
  flat decals when it says no.
- The map resolution is picked per frame from a 1024/1536/2048 ladder
  against a 0.45 world-pixels-per-texel target, because the light frustum
  is fitted to the world view and that swings 3x between the closest zoom
  and a maximised window at the widest. The frustum is snapped to whole
  texels, without which every shadow edge in the world crawls as you walk.
- Ambient occlusion, the genuine article: each vertex counts the
  neighbours crowding it and steps down once per neighbour, on top faces
  (four corners, three neighbours each) and now on upright faces too --
  the crease a wall rises out of, and the inside corners where flanking
  columns box it in. It is the complement of the shadow pass rather than
  a duplicate: the map draws the long directional shadow, this draws the
  dark seam in every corner the sky cannot see into, at scales finer than
  a shadow map texel.
- Plus a ground-contact term for the prebuilt prop quads -- per-pixel
  plants, signs and lone trees, and the round-tree stamps. Those arrive
  from Structures already finished, so the neighbour counting has no
  columns to count; what it can still say is that the floor blocks half
  the sky, so a voxel's first 6px of rise ramps back to full light. It is
  what stops a prop reading as pasted over the ground rather than
  standing on it, and outdoors it is most of what AO does at all, since
  trees and posts are nearly all prop geometry.
- One knob for the lot: `AO_STRENGTH` in `ChunkMesher` scales every term
  (they are written as darkening amounts, not multipliers), against a
  floor that keeps a crank from punching holes of pure black.
- The **V-CURVE** row in OPTIONS: the curved world, the Animal Crossing
  horizon. Every vertex is pushed down by the square of its horizontal
  distance from the camera's focus, and that is the whole effect -- a
  quadratic is nearly zero near its vertex, so the ground being played on
  stays flat, and the falloff accelerates, so the far edge rolls away over
  a near horizon and the town reads as sitting on a small sphere.
- It is deliberately NOT a fisheye. A fisheye is a LENS -- a screen-space
  warp -- which bends straight lines everywhere including right in front of
  the player, resamples every pixel to do it, and would leave this mode's
  art blurred and crawling. Bending the WORLD is one line in the vertex
  shader: lines near the camera stay straight and not a pixel is resampled.
- Displacing along Y only is what keeps it readable rather than
  nauseating: the drop depends on where a column stands, not how tall it
  is, so the world tips away and the buildings on it stay upright.
- Shadows and the wireframe ride along for free. Both are already worked
  out before the bend -- the shadow map in flat world space, the grid in
  model space -- so the bend carries them exactly as if they had been
  painted on, and neither the light frustum nor the grid needs to know the
  curve exists. `Voxel3D.project` applies the same drop on the CPU, which
  is what keeps the overworld's 2D field FX on their ground points.
- The strength scales with the view height, so a rung reads the same at
  every zoom, and the ladder is calibrated against the far edge of the
  visible ground rather than against nothing.
- `lib/ModSetting.lua`: the ladder/store/rows a setting of this mod's own
  needs, now that there are two of them. V-GRID's copy of it moved here.
- A **75 degree** rung on the VOXEL ladder, below the 15/35/50 it shared
  with the engine's TILT: low enough to read as a diorama shot from table
  height. Tilt could not have it -- its flat plane degenerates into a
  horizon line down there -- but geometry only gets more of itself to show.
- The **V-GRID** row in OPTIONS: a one-display-pixel wireframe along every
  voxel edge, 3D Dot Game Heroes style. Every mesh here is built one unit
  per voxel in its OWN model space, so the seams are that space's integer
  planes, and reading them in model space rather than world space is what
  keeps them glued to a thing however it is posed -- a character's slab
  leans back by the camera's pitch and its seams lean with it.
- The seams fade out where a voxel shrinks under about 3 display pixels.
  Survey zoom draws a world pixel at roughly a display pixel, and a wall
  seen nearly edge-on squashes one to nothing at any zoom; drawn anyway,
  the lines land closer together than they are wide and the wireframe
  stops being a wireframe and becomes a flat 45% dimming of the scene.
- `lib/VoxelGrid.lua` owns the toggle. It is NOT a pipeline: it owns no
  pass of the frame, it parameterises the voxel one, so it has nothing to
  put in `drawWorld` or `present` and the registry rightly rejects it. A
  plain mod setting instead -- `options:define` for the store and the mod
  manager's page, `ui.options.rows` for the row in OPTIONS next to VOXEL
  and T-SHIFT. Both rows read and write the one stored value.
- The wireframe is a SECOND COMPILATION of the scene shader rather than a
  branch inside it, because it needs shader derivatives (`fwidth`) -- the
  one part of the mode a driver can refuse. A refusal costs the grid and
  nothing else.
- `mods/DRAMATIC_SHAPE/tests/voxel_shadow_probe.lua`: reports the fitted
  frustum and the resolution rung, dumps the map itself, and shoots a
  stand point at every pitch. `SHADOW_SUN="kx,kz"` retunes the bearing for
  one run, `SHADOW_GRID=1` forces the wireframe on, and `SHADOW_ZOOM` pins
  the zoom, without which two runs are not comparable -- a driver inherits
  whatever the player left in `options.lua`, and the world view size (which
  the light frustum is fitted to) swings 3x across that range.

### Fixed

- Cycling palette modes with voxel mode on eventually killed the pipeline
  outright: `attempt to call field 'atlasImageData' (a nil value) --
  disabled for this session`. Nothing brought it back short of a restart.

  `TerrainAtlas` reads three engine seams to animate water and flowers in
  the terrain texture, and this build ships only one of them
  (`defaultAnimatedTiles`). The tile clock, `animFrame`, was already read
  guarded and simply degrades. `atlasImageData` was called straight -- but
  only down the branch where the mod had NOT baked the atlas itself, which
  is why it looked stable until a palette changed. Every mode with no world
  palette for the map (`PaletteFX.pal` answering nil), plus RED++ and any
  trueColor tileset, takes that branch, so the first map with animated
  tiles entered under one of them threw out of `drawWorld` and the engine
  disabled the pass for the session, exactly as it should.

  The seam is now read guarded like its sibling, and when it is absent the
  pixels are recovered rather than given up on. An atlas neither we nor
  RED++ replaced is the tileset art itself, so animation carries on from
  the art on disk. RED++'s per-map bake exists only as a texture --
  `getGbcAtlas` throws its `ImageData` away -- so that one comes back off
  the GPU: the atlas is drawn 1:1 into a canvas and read back, once per map,
  with the pass's own render target captured and restored around it (the
  usual `setCanvas()` would drop the rest of the frame). A driver that
  refuses the readback declines to animate and keeps the static atlas.
  Worst case now costs one animation, never the pipeline.

- Water and flowers did not animate in voxel mode at all, and had not since
  the mode shipped -- a silent one, since the terrain was otherwise correct.

  The tile clock is the third seam, and this build does not export it
  either. Being read guarded, it answered 0 forever instead of throwing,
  which pinned every animated tile at step 0. `animFrame` is a plain local
  in `TileRenderer`, but an upvalue of the exported `tick()`, so the mod now
  reads the real counter through it. That it is the ENGINE's counter is the
  point: the flat tile layer draws from the same number, so toggling voxel
  mode mid-cycle continues the animation rather than restarting it. A build
  that exports `animFrame()` outright is preferred; a build that hides the
  local falls back to wall time in 60Hz steps, which free-runs against the
  2D path but still moves the water.

- Toggling palettes in voxel mode flashed the flat 2D world for a moment on
  every switch.

  `PaletteFX.setMode` reloads the live map to rebuild its atlas, and this
  mod dropped that map's terrain mesh on any `map.reloaded` at all. Mesh
  builds are asynchronous, so the frames between the drop and the first
  rebuilt mesh had no terrain to draw -- and a voxel `drawWorld` with no
  terrain returns nil, which is exactly how the pipeline asks for the 2D
  fallback. The flash was the mod correctly reporting that it had nothing
  to show.

  The geometry was never stale: the mesher reads block layout and tile ids
  and never reads colour, and the palette lives entirely in the texture
  `TerrainAtlas` hands back per frame, keyed by palette and so already
  rebuilt by the next frame. A reload whose reason is `colors` now keeps
  the mesh, and the new palette lands on the diorama already on screen in
  one frame. Every other reload -- warps re-entering a map, hot reload, a
  replaced block -- still drops it.

- Every non-colour palette mode rendered as SGB in voxel mode: GRAY and
  both INVERTED modes came through as the map's blue.

  `paletteFor` hands a pipeline the map's RAW SGB zone palette. The flat
  path runs that through `PaletteFX.effectiveColors` on its way to the
  shade-remap shader, and that call is where the non-colour modes actually
  happen -- OG and OG INV swap in the DMG greys (reversed for the latter),
  CLASSIC swaps in the green set, GBC INV permutes the zone's own shades,
  and only GBC and RED++ pass through. This pass bakes colour into the
  atlas and the sprite sheets ahead of the draw rather than shading at blit
  time, so it never reached that call and painted the raw zone palette in
  every mode.

  Both bakes now run the same transform the shader would have. Terrain and
  characters go through one resolve, so they cannot disagree about what
  mode is on.

- VOID FILL did nothing in voxel mode, in two separate ways.

  **BLACK crashed the build.** The mode is not a block at all --
  `TileRenderer.borderBlockFor` answers `false` for it -- and `Structures`
  added 1 to that `false`. The arithmetic threw, which failed the mesh
  build for every map in the neighbourhood, which left the mode with no
  terrain and dropped it to the flat 2D path entirely. It now builds no
  ring: `tileLookup` answers nil past the body and those keys are never
  written, which the rest of the file already copes with -- every
  neighbour query in it reaches one step outside the analysed range and
  reads nil for its trouble, so an absent cell is the shape "nothing" has
  always had here.

  **WATER changed nothing on screen.** The ring is BAKED INTO THE MESH in
  this mode rather than drawn each frame, and nothing dropped the cache
  when the option moved, so the old ring simply stayed until the meshes
  were invalidated for some other reason. The pipeline's update hook now
  polls `TileRenderer.voidFill` and invalidates on a change -- polled
  rather than hooked because the engine changes it from three places (the
  options row, `applyOptions` on load, `setVoidFill`) and none of them
  announces it, and checked ahead of the active() gate so switching it
  while voxel mode is off still drops what is cached.

  `mods/DRAMATIC_SHAPE/tests/voxel_void_probe.lua` walks the three modes
  and reports the border block, whether the mesh built and whether the
  scene took the 3D path. It deliberately does NOT invalidate the cache
  itself, since doing so would hide the second half of this.

- Water and flowers did not animate. The 2D path animates them by
  OVERDRAWING the animated cells on top of the static tile layer each
  frame, which a single static mesh has no equivalent of -- the geometry
  samples one texture and that is that. So `TerrainAtlas` animates the
  texture instead: a private copy of the atlas whose animated tile slots
  are rewritten when the step advances, which moves every instance of that
  tile across the whole mesh at once. Which is what the Game Boy does in
  the first place (`home/vcopy.asm` rewrites the tile's VRAM bytes); the
  overdraw is the port's workaround for a tile layer, not the original.
  ~130 pixels of work three times a second, on the same
  `TileRenderer.animFrame` clock the 2D path uses, so the two can never
  disagree about which frame they are on.
- The frame files (`flower1..3.png`) are raw grayscale and have to land on
  the colours of the tile they replace, but the two recolour paths do not
  share a rule -- SGB bakes one world palette over everything, RED++ picks
  a palette group per tile graphic. So the shade mapping is LEARNED from
  the atlas: read the static tile's slot in the raw art and in the finished
  atlas side by side and ask what each shade became. Right under both
  without this file knowing which one ran.
- Terrain art was off the pixel grid by up to half a pixel, with one art
  pixel per tile sampled twice and another never at all. A tile is 8
  texels across 8 world pixels -- one texel per pixel exactly -- and
  `ChunkMesher`'s uv inset squeezed that art into a 7-texel sample range
  while the quad still covered 8 world pixels, so it advanced 7/8 of a
  texel per pixel and drifted. The inset exists to stop the rasteriser
  reaching a neighbouring tile along a shared edge, but half a texel was
  fifty times more than that needs: 0.02 is as safe (interpolation error
  is nowhere near it) and drifts 0.25% of a pixel across a whole tile.
  Nothing showed the fault until the voxel wireframe drew the grid those
  pixels were supposed to be sitting on.

### Changed

- `Voxel3D.SHADOW_KX/KZ` are -0.85 / -0.55, from +0.30 / +0.45: the sun
  crosses to the southeast and drops from 62 degrees to 45. The bearing
  leans WEST of northwest on purpose -- a character is drawn as a slab
  leaning away from the camera, which covers the ground due north of its
  feet, so a shadow thrown straight up-screen lands entirely underneath
  the figure casting it and is never seen.
- `Voxel3D.SHADOW_ALPHA` 0.32 -> 0.40, a quarter darker.
- `FACE_SHADE` east 0.78 -> 0.84 and west 0.78 -> 0.72. The two were equal
  because the old sun sat due northwest and they were symmetric about it;
  under a southeastern sun east is a lit flank and west a shaded one.
- A character's shadow lookup runs off the UPRIGHT card the sun saw, not
  the leaning slab the camera sees (`Voxel3D.draw`'s `sunModel`). Casting
  the leaning slab instead would shrink every shadow to nothing as the
  camera flattened toward top-down; looking up with the leaned position
  put each sprite's own card across its front.
- The contact-shadow term in `ChunkMesher` was a one-directional stripe
  keyed to a northwestern sun -- two neighbours, one corner, top faces
  only. It is now the ambient occlusion above.
- The light frustum is fitted to the ground the CAMERA CAN SEE rather than
  to a view-sized box around the focus, and both of its margins are now
  asymmetric -- for opposite reasons. The camera sits south of its focus
  and looks north, so the ground it sees runs far north and barely south;
  the sun sits southeast, so the casters for that ground stand south and
  east of it. Paying for a view-sized box plus caster margin on all four
  sides covered about a third of what was on screen at 75 degrees, and
  overpaid at 15.
- Shadows ease off at the frustum's rim instead of ending on it. Past the
  low rungs the horizon is further out than any box worth paying for, and
  a covered region that simply stops draws a hard line across the middle
  distance where every shadow ends at once.

The Pokemon Center interiors. One `POKECENTER` group in
`data/voxel_heights.lua` plus one new class, and because
VIRIDIAN_POKECENTER places every tile the tileset's other maps use, the
one pin set covers all eleven Centers and the Celadon Hotel.

### Added

- A `counter` class (8px, upright): half-cell furniture. One 8px band,
  so exactly the drawing's bottom row stands up as the front and every
  row above it rides the top face in drawn order. `table`'s 12px could
  not be retuned for it; the houses share that class.

- `tilesets.POKECENTER` in `data/voxel_heights.lua`. Before it, the
  detector merged the wall-touching counters and healing machines into
  the wall band and towered them 3-6 blocks, flattened the machines'
  near-black screens to void, read the pillar bases, plant pots and
  machine bodies as ponds (the $14/$32/$48 stale-cache water fallback),
  boxed each plant pair into one hedge cube, and extruded the lounge
  seat -- a PERSON is drawn into its tile art -- into a monolith wearing
  his face.
- The pins, by shape: the wall band, windows, poster, pillars and the
  16px machine bodies are `wall`; the counters (with the nurse's tray)
  are `counter` and the PC's desk is `table`; the machine screens and
  the PC are `billboard`, standing on the pinned boxes below them; the
  potted plants are `prop` standees like every other interior plant.
- The lounge couch with the man sitting on it is a `counter` box: its
  bottom row stands up as the couch's front and the cushion and the man
  ride the top face, each drawn exactly once.
  He cannot be stood upright, and the reason is structural rather than a
  tuning question. His skin pixels span two tile rows and stop dead at
  the row 9/10 seam; folding two rows upright requires both to share a
  class, which makes the box two tiles deep, and a fully folded box
  repeats its north row across its whole top face. So every upright
  arrangement puts his head on screen two or three times -- as a 16px
  seat-back, on the front and twice more on the top; as a 32px bookcase,
  a cabinet taller than the room's own walls. Dropping the seat in front
  of him to floor level only changes which copy you see. Nor can he be a
  standee: the drawing has no floor margin, so all three non-black
  shades touch the cluster rim and the mask drains 307 of its 420
  interior pixels -- 46% of him even segmented alone, because his skin
  is the same light shade as the couch behind him.
- Survey evidence: full before/after passes of VIRIDIAN_POKECENTER at
  15/35/50 degrees, plus spot-checks of CELADON_POKECENTER and
  CELADON_HOTEL (shared tileset, both inherit correctly) and of
  REDS_HOUSE_1F, OAKS_LAB and VIRIDIAN_CITY (unchanged -- the new class
  is additive and no other tileset lists it).

## 1.3.0

Terrain meshing goes asynchronous, instanced and bounded. The first voxel
frame used to build every neighbourhood map synchronously (a ~2.4s
freeze), retain every map's analysis forever (gigabytes over a
cross-region trek), and string stray pixels along map seams.

### Changed

- Mesh builds stream in the background. `ChunkMesher` queues per-map
  build jobs and `pump()` -- driven from the pipeline's update -- runs
  them inside a few-millisecond frame budget (`lib/BuildBudget.lua`
  suspends the build coroutine mid-loop when the slice is spent). The
  camera tween holds at flat until the current map's terrain exists, so
  toggling voxel mode shows a handful of flat frames instead of a frozen
  one; neighbours pop in as they finish. Warp fades prefetch the
  destination (the pipeline update ticks while the Transition covers the
  screen, with a wider pump slice), so a door exit lands on terrain that
  is already built.
- Vertex packing goes through FFI into one native buffer
  (`Mesh:setVertices(ByteData)`) instead of a Lua table per vertex --
  the headless table path remains for the pure `geometry()` API and its
  suite.
- Round-tree hulls are carved once per (tileset, art, ground set) and
  kept as stamps -- template plus cell offset, expanded during vertex
  packing -- instead of materialized per-cell quad tables. A route's
  border forest was ~500 quads x hundreds of cells of retained heap.
- Mesh and analysis caches evict down to the live neighbourhood (current
  map + rendered neighbours, plus one set of history so a house
  round-trip keeps the town warm). Evicted meshes are released
  explicitly. Memory over Pallet -> Mt Moon: was ~2.9GB and monotonic,
  now oscillates between ~90 and 200MB.

### Fixed

- Stray pixels along map seams: ring props (border-tree hulls) whose
  quad CENTER sat exactly on a neighbour body's edge line escaped the
  strict point-in-rect mask and survived as fragments of otherwise
  dropped trees. Object quads now keep/drop by their full extent,
  boundary inclusive; props straddling the body edge also stay whole
  instead of shedding their outer half.
- The one-step "ledge hop" when crossing a connection into a tree-ringed
  map: the seam step stands the player one cell off the new map, where
  `Map:cellTile` border-extends into the borderBlock -- a raised tile on
  maps ringed with trees. Off-map ground now reads as height 0 (the
  departed neighbour's flat walkway, which is what is actually rendered
  there).

## 1.2.0

Buildings stop being boxes wearing their own elevation. A profiled
building is voxelized from its own sprite, band by band -- the pipeline
written up in `assets/docs/buidling_to_voxel/`.

### Added

- `lib/Buildings.lua`: a building archetype. Where the volume path folds a
  whole drawing upright (roof, facade and sloped ends alike) into one box,
  this classifies each BAND of the drawing by the 3D surface it depicts and
  applies the matching operation: top-facing rows lay flat over the
  footprint, the facade extrudes straight back, an awning band juts past
  the walls, and the drawn taper at the ends becomes a stepped slope in
  elevation. Every visible voxel carries a real texel of the drawing, so
  the model recolours with the atlas.
- A `buildings` section in `data/voxel_heights.lua`. A building is matched
  by its exact tile grid (the drawings are catalogued in `assets/docs/buildings/`),
  so one entry covers every map that places the same art -- Red's house,
  Blue's house, Bill's, the Copycat's and the two Fuchsia houses are one
  seven-placement entry, and Oak's lab is a second. Only the band table is
  authored; the silhouette, the taper rate, the eave height and every
  window and doorway are measured off the pixels.
- The flat-roofed civic block and its sixteen relatives -- every Pokemon
  Center and every Poke Mart, Fuchsia Gym, the museum, the Game Corner,
  Celadon Mansion and its department store, the Power Plant, the Route 5
  and Route 22 gates, Silph Co and five anonymous scenery blocks. They are
  one architecture drawn at eleven different footprints, from 4x4 cells up
  to Silph Co's 8x12, and they share one band table: their lattice is drawn
  from straight above, so the measured taper comes out flat and the whole
  band is depth under one level roof. No new roof mode was needed -- the
  drawn profile was always the shape, and a drawing with no taper simply
  yields a level one.
- Pewter's museum hall (`assets/docs/buildings/B24`). It is the one
  sloped-roof building in this pass, and the only one so far whose roof
  texture is not a plain repeat: the drawing states its own period by
  repeating the whole lattice-and-course motif, rows 8..31 again at 32..55,
  so the cycle is 24 rows and the roof carries its drawn courses across the
  depth instead of a bare lattice. The band below them is the roof's
  fascia, wider than the wall it covers, so it belongs to the roof and
  lands on the south rim. Note the museum is TWO drawings: this hall and
  the east entrance beside it, which is B18 and shares its drawing with the
  Route 2 gate.
- The rest of the 2:1 sloped-roof buildings: both gym drawings (the
  standard one at Cinnabar, Pewter, Vermilion and Viridian plus the
  Fighting Dojo, and the wider Celadon / Cerulean / Saffron one), the 4x2
  cottage that houses Mr Fuji, the Cubone house, Bill's grandpa, the Name
  Rater and the Viridian school, Cerulean's three wide houses, the day
  care, and three scenery blocks -- among them B01, which at 19 placements
  is the commonest drawing in the game. Each one's roof band is pixel for
  pixel one of the three already authored, so they take that sibling's band
  table unchanged: 16 rows for Red's house's, 32 for Oak's lab's, 64 for
  the museum's.
- The Safari Zone rest houses and the Victory Road entrance, the first
  buildings outside the `OVERWORLD` tileset -- `buildings` is keyed by
  tileset and until now only had the one section. The rest house's
  corrugated roof repeats every 5 rows rather than the overworld lattice's
  8, which is the point of `roofCycle` being authored per building.
- Route 10's scenery block, via a new `seal` field. Its drawing has no
  black base course -- it ends on a row of light brick -- so the silhouette
  flood climbed in from the south border through the mortar and hollowed
  the wall out, leaving 72% of the sprite in 65 pieces. `seal` names the
  sides a drawing runs off rather than closing, and the flood does not seed
  there: sealed, it is 95% in one piece, and the model is its twin the
  museum's. No other building sets it, and none changes by a voxel.
- Together these take the mod to 31 of the catalogue's 34 drawings and 144
  of its 147 placements. The last three, and why each resists, are written
  up in `assets/docs/buildings/REMAINING.md`.
- A roof no longer runs past the drawing's own silhouette. These sprites
  are inset from their boxes, and the columns outside the inset carry no
  roof: they now get none, and the fascia belongs to the outermost columns
  the drawing actually paints. Before, they raised a four-voxel slab of
  black kerb the full depth of the building, flanking its walls at ground
  level. Nothing shipped hit this -- Red's house and Oak's lab are drawn
  edge to edge -- so no existing model changes by a single voxel.
- Windows and doorways sink a voxel behind their frames, found rather than
  listed: a pane is a non-black region the drawing seals off behind its own
  black outline. A nested frame (the door's own little window) layers for
  free.
- `tools/building_voxels.py`: the reference implementation of the same
  algorithm, with the geometric asserts and isometric previews Stage 5 of
  the methodology calls for. It and the runtime agree exactly on voxel and
  shell counts for all 19 templates -- 96,617 / 12,866 for Red's house up
  to 3,715,963 / 146,762 for Silph Co, which ship as 3,410 and 13,994
  quads. Its slope asserts read the drawn columns only and stand down for a
  roof with no taper, where the check is that the roof is level instead;
  its previews fit the projection to the model rather than to a fixed
  camera, so a building taller or deeper than the first two still lands on
  the canvas.

### Changed

- A voxelized building is as tall as its facade plus its roof slab rather
  than as tall as its drawing: the roof rows are DEPTH now, not height, so
  Red's house is 36px over a 4x3-cell plot instead of a 48px cube.
- Round trees (the `cylinder` pin: lone canopies and the border tree
  wall) stop being lathes -- the sprite wrapped around a 12-segment
  column read as exactly that, art smeared on a barrel. Each cell is now
  a real voxel hull: the canopy is segmented out of its cell as the
  darkest-pixel outline plus everything it encloses (which also drops
  the background grass that used to inflate every row to full width, and
  the cast shadow under the ball), and each mask row runs its own span's
  circular chord in depth -- the front view is the sprite pixel for
  pixel, the plan view is the sprite's width profile turned in depth.
  Dithered art with no closed outline (the tree wall) falls back to
  light-shades-only flooding, per the methodology doc's boundary rule.
  Sides de-outline like building extrusions so flanks read as canopy
  rather than solid black, and dome caps keep their outline on the rim
  while the interior samples the canopy a couple of rows deeper.
- A `post` standee pool, pinned for the overworld's vertical fence-post
  cell (tiles 14/85 -- across every map the pair appears only as this
  cell). The detector already turns HORIZONTAL fence runs (tile 57) into
  per-post standees, but a vertical run of repeated cells trips its
  scenery-repetition guard and fell to the volume path as a
  fence-textured tower (Viridian's west line, Route 25).
  `post` extracts every CELL as its own cluster -- pooled clustering
  would stand the whole line up as one drawing-tall slab at one depth --
  and classifies pixels the way the detector does (non-white is body)
  rather than by the pinned-prop outline rule, which would strip the
  posts to black skeletons; at the detector's own 6px depth, pinned and
  detected fences look alike.
- Town signs move from the `billboard` pool to a new `signpost` pool: the
  same per-pixel standing slab, but 2 voxels thin instead of 10. A sign
  is a plate on a stick, and the standee body that keeps a TV from
  vanishing at shallow angles read as a solid block of furniture here.
- The ground under a round tree matches the tree's own drawn background
  instead of the map's commonest ground tile. The hull's segmentation
  already knows which pixels are NOT the tree; those pixels are scored
  against every flat ground tile the map places and the closest art
  wins, per template -- so border trees drawn over checker grass stand
  on checker grass even on a map that is mostly pale path (the old
  fallback painted path under every mid-forest tree, which has no flat
  neighbour to vote with). The drawn cast shadow stays out of the score:
  no ground tile carries a shadow, and its darks would drag every match.

### Fixed

- The generic town-house tileset (`HOUSE` -- Blue's house, Daisy at her
  table, and eighteen more homes, the schoolhouse and the trashed house
  among them) is now pinned in `data/voxel_heights.lua` the way Red's
  rooms already were: the dining table stops towering as a wall-height
  volume and sits at table height with its front folded upright, stools
  become seat-high boxes that characters sit on, the corner potted
  plants become per-pixel standees instead of texture-smeared box
  stacks, the bookcases get clean capped tops, and the wall band (with
  its window, picture and the schoolhouse blackboard) stays one 16px
  face.  The schoolhouse's open book stands on the pinned tabletop as a
  cutout, and the trashed house's ransacked table corner keeps table
  height.
- Interior door mats lie flat again in Red's and the generic houses.
  Their collision tile is $14, which the engine's stale-cache fallback
  counts as water in every tileset, so the rug recessed into a pond lip;
  a `ground` pin now overrides the water read.

## 1.1.0

Interior furniture gets the shapes it depicts
(mods/DRAMATIC_SHAPE/tools/voxel-survey.md is the procedure that found and
verified these).

### Added

- Furniture shape classes in the profile: `bed` (a low slab wearing its
  top-down art), `table` and `desk` (boxes at their drawn height whose
  faces fold the artwork up), `relief` (a prop drawn from above -- a
  game console -- lying flat and extruding a few voxels inside its
  outline), the standee pools `billboard` (10px) / `prop` (5px) /
  `stool` (5px, and characters standing on its walkable cell sit at
  seat height) / `cutout` (one voxel: pure profile, for the vase on the
  table), and the stair archetypes `stair_e`/`stair_w` (a rising flight
  of real steps) and `stair_down_e`/`stair_down_w` (a sunken stairwell
  descending below the floor -- stairs that lead down).  Separate pools
  cluster separately, so touching drawings never merge into one cutout.
- Standee clusters split into per-pixel connected components, each
  standing on its own feet in the depth band of the row it is drawn in:
  two stools stacked in adjacent cells become two stools, and no
  fragment of a drawing ever floats at its bounding-box height.  A
  `cutout` keeps only its largest component -- a cast shadow's drawn
  edge is background, not a floating scrap.
- `bookcase` class: free-standing shelf drawings collapse in ranks onto
  one-cell-deep boxes at their full drawn height, back rows becoming
  hidden floor; the trim row above a rank -- undetected structure or a
  row pinned `table`, since the same trim tiles cap other furniture --
  is adopted as its cap.  Pinned for Oak's Lab (`DOJO`).
- Oak's Lab tables pinned `table`: the starter-ball display and the
  north tables stand at real table height, the display frame's black
  corner brackets no longer auto-extract into standing prisms, and the
  Poke Ball / Pokedex sprites ride the authored height onto the
  tabletops.
- Pinned props drawn directly above a pinned box stand ON it: the PC
  monitor on its desk, the flower pot on the dining table.
- Profile pins for `REDS_HOUSE_1` / `REDS_HOUSE_2` (Red's house and the
  Copycat's, both floors): bed, stools, tables, PC desk with its
  standing monitor, bookcases, TV standing on the floor behind the game
  console's relief, potted plant, flower pot, both staircases, and the
  wall/window band.
- `mods/DRAMATIC_SHAPE/tests/voxel_survey.lua`: screenshot-survey driver
  behind the repeatable inspection procedure (SURVEY_MAP / SURVEY_SPOTS /
  SURVEY_LEVELS / SHOT_DIR), documented in
  mods/DRAMATIC_SHAPE/tools/voxel-survey.md.

### Changed

- Pinned props are segmented the way the art is authored: objects wear a
  black outline, so background is the shades touching the cluster's edge
  (white floor around a TV, grey tabletop around a vase) flooded in from
  the aprons; the outline, its interior, paint whites and anything they
  enclose survive -- pixel-perfect cutouts on any surface.
- Indoor structure analysis floods background from all four aprons and
  accepts ground contact on any side (outdoors keeps the south-only rule
  that protects roofs), so face-on furniture drawings voxelize per pixel
  instead of rising as wall-height volumes.
- Profile-pinned standees are 10px deep (detected props stay 6px), so a
  deliberate object like a TV keeps a body at shallow camera angles.
- Authored upright boxes fold their artwork up every face (flanks and
  back wear the front stack darkened) and top faces keep the drawn
  tabletop: face-on rows wear the row above the fold instead of
  repeating their front art lying flat, and a run that folded entirely
  tops with the furniture row drawn above it (a bookcase's shelf trim).
- Characters no longer ride a pinned stair tile's class height: stairs
  are walked through at floor level, fixing the step-up onto thin air in
  front of stairwells.

## 1.0.0

First release, ported from the engine-internal voxel branch onto the
`render_pipelines` mod API.

### Added

- `voxel` render pipeline: 3D diorama overworld with extruded terrain,
  depth-buffered occlusion, leaning sprite billboards, drop shadows and
  contact AO. VOXEL options row and hotkey `6` (OFF / 15 / 35 / 50).
- `tiltshift` render pipeline: a `worldPresent` post-process giving the
  miniature-photo look. T-SHIFT options row and hotkey `9` (OFF / 1 / 2 / 3).
- Carved voxel models for 67 overworld sprites, plus the
  `tools/build_voxels.py` that produced them.
- `data/voxel_heights.lua`, the hand-authored tile shape profile.

### Changed from the pre-mod version

- The level is no longer the mod's to keep. The engine owns the ladder, the
  options rows, the hotkeys, persistence and the TILT exclusion; the mod
  keeps only the camera-angle tween.
- Persistence moved from `save.options.voxel` / `save.options.tiltshift` to
  `save.options.pipelines.voxel` / `.tiltshift`.
- Hotkeys moved from `4`/`9` to `6`/`9`: the fork already uses `4` for
  survey zoom.
- The tilt-shift pass is a declared `worldPresent` stage rather than a call
  spliced into the world draw, so it composes with any world pipeline
  instead of only this one.
- The cut-tree animation now draws in voxel mode; the pre-mod version
  omitted it from the 3D field-effect list.
