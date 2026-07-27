-- Voxel world mode: the shape PROFILE -- hand-authored pins over the
-- automatic structure detector, the way a 3dSen game profile pins a
-- graphic to a geometry type.
--
-- Hand-authored by this mod, and read only from here: unlike the tables the
-- ROM extractor writes into the player's own cache, nothing below is
-- extracted, derived or copied from the ROM.
-- Nothing here reaches gameplay, collision or scripts; an entry can only
-- ever change how a tile LOOKS in voxel mode.
--
-- Most of the world needs no entry. The runtime detects structures on its
-- own (src/render/voxel/Structures.lua): it flood-fills each connected
-- drawn thing, voxelizes small props per pixel at their real drawn height
-- with transparency (a 2-row plant is a 16px-tall silhouette, not a box),
-- and raises everything else as a volume whose height is measured from the
-- drawing itself -- repeat-aware, so a 6-row house is 48px while a 40-row
-- border forest is rows of 16px trees, not a monolith.
--
-- Listing a tile here BYPASSES that detection: the tile takes the class's
-- height and art mode, always. Use it where the detector reads art wrong,
-- or from a mod to pin its own tiles. Resolution order per tile:
--
--   1. a group listed under tilesets[<id>] below        (this profile)
--   2. the tile sits in a water cell                    -> "water"
--   3. the tile sits in a WALKABLE cell                 -> "ground"
--   4. tile-level fallback: the map's water set -> "water", its walkable
--      list -> "ground", anything left over             -> "wall"
--
-- Rules 2-3 work at CELL granularity (16x16, the walk grid) because that
-- is the granularity collision actually has: the engine judges a cell by
-- its bottom-left tile alone, so the other three tiles of a cell carry no
-- collision meaning -- flowers and grass tufts sit in walkable cells and
-- must stay flat ground even though no walkable list names them.
--
-- Classes (heights in world pixels; a map cell is 16x16):
--   ground / water / void   flat; water recesses so shorelines show a lip
--   ledge / roof / bed      box with the art on its TOP face; partial side
--                           faces crop the art (a 6px ledge face is the
--                           bottom of the lip drawing; a bed is its
--                           mattress drawn from above, lying low)
--   wall / tree / fence / sign / counter / table / desk
--                           box whose SOUTH face folds the 2D artwork
--                           upright, 8px band by band; authored boxes fold
--                           every face and wear their top row's art on top.
--                           A counter is half a cell -- one band, so its
--                           drawn front panel stands and its top stays on top
--   stair_e / stair_w       real steps rising toward the named side, the
--                           full cell deep, treads and slices textured
--                           from the drawn staircase
--   stair_down_e / _down_w  a sunken stairwell: the cell opens into a
--                           hole with steps descending toward the named
--                           side -- stairs that lead DOWN a floor
--   relief                  a prop drawn from above (a console on the
--                           floor): the drawing stays flat and the
--                           pixels inside its black outline extrude a
--                           few voxels, art on top
--   bookcase                a free-standing shelf drawn tall: each rank
--                           collapses onto a one-cell-deep box at its
--                           full drawn height; back rows become hidden
--                           floor, and an unpinnable trim row above
--                           becomes the cap
--   billboard / prop        a prop drawn face-on: a standing per-pixel
--                           cutout, black-outline segmented; drawn above
--                           a pinned box it stands ON that box (a
--                           monitor on its desk).  prop is a second pool
--                           so two touching cutouts stay separate
--
-- A tileset entry may also carry `prop_ground` (not a class): a map of
-- prop tile id -> ground tile id naming the tile painted under that
-- pinned prop, overriding the flat-neighbour vote -- the cuttable bush
-- stands on the grass Cut leaves behind, whatever borders it.
--
-- Whole BUILDINGS are not tile pins -- one drawing packs a roof seen from
-- above, a facade seen face-on and sloped ends as diagonal silhouettes,
-- and no single class covers that.  They live in the `buildings` list at
-- the bottom of this file, as a band table over the drawing's rows.

return {
  version = 1,

  -- class -> height in world pixels
  heights = {
    ground = 0,
    water = -2,
    void = 0,
    ledge = 6,
    fence = 10,
    sign = 12,
    wall = 16,
    tree = 16,
    roof = 28,
    bed = 7,
    stool = 8,
    counter = 8,
    table = 12,
    desk = 24,
    prop = 16,
    cutout = 16,
    relief = 3,
    bookcase = 32,
    stair_e = 16,
    stair_w = 16,
    stair_down_e = 16,
    stair_down_w = 16,
  },

  -- Only tiles the detector must not touch need listing. Tile ids are
  -- indices into the tileset's own 8x8 atlas.
  tilesets = {
    OVERWORLD = {
      -- the hop-down edges named by data.field.ledges' ledgeTile: their
      -- art is a ground lip seen from above, which the detector would
      -- otherwise raise as a wall
      ledge = { 13, 29, 39, 54, 55 },
      -- trees are drawn ROUND -- the lone canopy (42/43/58/59) and the
      -- border tree wall (64/65/80/81, blockset $0F). Boxes and per-pixel
      -- cutouts both read wrong for them; the cylinder archetype carves
      -- one voxel ball per 16x16 cell from the canopy's darkest-pixel
      -- outline, round in depth, so tree rows become rows of real canopies
      cylinder = { 42, 43, 58, 59, 64, 65, 80, 81 },
      -- the town sign (blockset 8's SE cell): a standing per-pixel slab
      -- 2 voxels thin, transparency respected -- never a solid box
      signpost = { 70, 71, 86, 87 },
      -- the fence posts drawn in VERTICAL runs (14 the post tops, 85
      -- the bottoms -- across all 222 maps the two tiles pair only in
      -- this one cell). The detector already turns the HORIZONTAL runs
      -- (tile 57) into per-post standees, but a vertical run of repeated
      -- cells trips its scenery guard and fell to the volume path as a
      -- fence-textured tower. `post` extracts each cell alone, so these
      -- render as the same thin posts, marching north
      post = { 14, 85 },
      -- the cuttable bush ($2D/$2E/$3D/$3E, the four tiles Cut deletes
      -- -- across the whole tileset they appear only in the five
      -- cut-tree blocks): a standing per-pixel cutout 5 voxels deep,
      -- black-outline segmented with the pixels the outline encloses
      -- kept, its drawn grass dither flooding away as background
      prop = { 45, 46, 61, 62 },
      -- the ground painted under those pinned props, by the prop tile's
      -- own id: the bush stands on plain grass ($2C) -- the very tile
      -- Cut leaves behind (field.cutTreeSwaps' after-blocks) -- rather
      -- than whatever flat tile its neighbours vote
      prop_ground = { [45] = 44, [46] = 44, [61] = 44, [62] = 44 },
    },

    -- The badge gyms and Bruno's room (one tileset): the bird statues
    -- that flank every gym's aisles, and Lt. Surge's trash cans.  A
    -- statue is one cell of figure ($02/$38/$12/$13) drawn over one
    -- cell of plinth ($22/$23/$32/$33); the trash can is one cell
    -- ($0B/$0C/$1B/$1C, blocks 38/39 only).  Across the whole blockset
    -- none of these tiles appears anywhere else.  The plinth stays a
    -- SOLID 16px block; the figure stands ON it as a per-pixel cutout
    -- 5 voxels deep (the thin `prop` pool), collapsing to the plinth's
    -- single cell of footprint (Structures' wall-support rule); the
    -- can is the same 5-voxel cutout at floor level.  Both are
    -- black-outline segmented -- backgrounds flood away, the pixels
    -- the outline encloses stay.  Everything stands on the gyms' main
    -- floor tile ($11), which is also Bruno's floor.
    -- (The round boulder drawn beside some statues, $07/$08/$17/$18,
    -- is NOT pinned: it also tiles wall-to-wall as Pewter's rock rows,
    -- which are scenery for the detector, not a lone prop.)
    GYM = {
      wall = { 34, 35, 50, 51 },
      prop = { 2, 56, 18, 19, 11, 12, 27, 28 },
      prop_ground = { [2] = 17, [56] = 17, [18] = 17, [19] = 17,
                      [11] = 17, [12] = 17, [27] = 17, [28] = 17 },
    },

    -- ledge pairs from data.field.tilePairs
    CAVERN = {
      ledge = { 5 },
    },
    FOREST = {
      ledge = { 46 },
    },

    -- Oak's Lab (the tileset also serves the Fighting Dojo and Lance's
    -- room, which use none of these tiles).  The free-standing shelf
    -- ranks: book rows and base pinned; the shared trim tiles above
    -- (41/42, also the lab tables' corners) are adopted as caps by the
    -- bookcase builder rather than pinned.
    DOJO = {
      bookcase = { 13, 14, 29, 30 },
      -- the lab tables (the starter-ball display and the north tables):
      -- 41/42 are also the shelf trim the bookcase builder adopts as
      -- caps, which its cap rule allows for authored table rows.
      -- Pinning stops the display frame's black corner brackets from
      -- auto-extracting into standing prisms, and the ball/Pokedex
      -- sprites ride the table's authored height.
      table = { 41, 42, 57, 59, 78, 79 },
    },

    -- Red's room and the Copycat's room (one tileset).  The detector reads
    -- this furniture as wall-height volumes -- and merges the wall-touching
    -- table and desk INTO the wall, towering both -- so every object here
    -- is pinned to the shape it depicts.
    REDS_HOUSE_2 = {
      -- the wall band with its windows stays one 16px face
      wall = { 0, 36, 37, 52, 53 },
      -- the bed: a mattress drawn from above, half a block high
      bed = { 45, 46, 47, 61, 62, 63 },
      -- stools: a seat-high box, seat art on top, legs on the front
      stool = { 2, 3, 18, 19 },
      -- the long table under the windows, and the PC desk's body with
      -- its hutch row -- the monitor standing on it is pinned below
      table = { 38, 39, 41, 42, 43, 44, 50, 51,
                58, 59, 60, 66, 67 },
      -- standing per-pixel props, black-outline segmented.  The PC
      -- (64/65 monitor top, 32/33 monitor bottom + keyboard) is drawn
      -- above the desk's body, so it stands ON the desk; the TV stands
      -- on the floor
      billboard = { 6, 7, 22, 23, 32, 33, 64, 65 },
      -- the potted plant: mostly silhouette, so it takes the THIN
      -- standee pool
      prop = { 8, 9, 24, 25, 68, 69, 70, 71 },
      -- the small potted plant on the table: a paper-thin profile
      -- cutout standing on the tabletop, its leaf crown (in 40) included
      cutout = { 40, 54, 55, 56, 57 },
      -- the game console in front of the TV is drawn from above: it
      -- lies flat and extrudes a few voxels inside its outline
      relief = { 14, 15, 30, 31 },
      -- the staircase leads DOWN to 1F: a sunken stairwell.  The player
      -- enters at the east lip and the flight descends westward, the way
      -- the drawn railing slopes (high at the east, low at the west)
      stair_down_w = { 10, 11, 26, 27 },
    },

    -- Red's and the Copycat's ground floor (one tileset, same atlas as
    -- the floor above).  Bookcases, dining table with its flower pot,
    -- stools, the TV on the floor, and the staircase up.
    REDS_HOUSE_1 = {
      wall = { 0, 36, 37, 52, 53 },
      stool = { 2, 3, 18, 19 },
      -- the dining table (38-44/58-60); its top row also caps the
      -- bookcases below
      table = { 38, 39, 41, 42, 43, 44, 58, 59, 60 },
      -- the bookcase bodies: tall shelf boxes; their drawn top-edge row
      -- (38/41, pinned table above) becomes their top face
      desk = { 34, 35, 48, 49, 50, 51 },
      -- the TV on the floor
      billboard = { 6, 7, 22, 23 },
      -- the small potted plant on the table: a paper-thin profile
      -- cutout standing on the tabletop, its leaf crown (in 40) included
      cutout = { 40, 54, 55, 56, 57 },
      -- the staircase leads UP to 2F: a rising flight climbing east
      stair_e = { 12, 13, 28, 29 },
      -- the front-door mat: its collision tile is $14, which the engine's
      -- stale-cache fallback counts as water in every tileset, so the rug
      -- would recess into a pond lip.  It is a flat rug on the floor
      ground = { 4, 20 },
    },

    -- The generic town house (Blue's, Daisy at her table, and eighteen
    -- more homes; the schoolhouse and the trashed house reuse it too).
    -- Same failure as Red's rooms: the detector reads the furniture as
    -- wall-height volumes and towers the table, so every object is
    -- pinned to the shape it depicts.
    HOUSE = {
      -- the wall band stays one 16px face: blank courses, the window,
      -- the framed picture, and the schoolhouse blackboard (72-75/88-91)
      wall = { 0, 36, 45, 46, 52, 61, 62, 72, 73, 75, 88, 89, 90, 91 },
      -- stools: a seat-high box that also seats Daisy
      stool = { 2, 3, 18, 19 },
      -- the dining table (top edge 38/41 also caps the bookcases);
      -- 80-83 are its ransacked corner in CERULEAN_TRASHED_HOUSE, which
      -- stays at table height rather than de-merging into a wall stub
      table = { 38, 39, 41, 47, 54, 57, 58, 59, 60, 80, 81, 82, 83 },
      -- the bookcase bodies: book ranks (14/15 left pair, 48/49 right)
      -- and the base course; the drawn top edge (38/41, pinned table
      -- above) becomes their top face
      desk = { 14, 15, 30, 31, 48, 49 },
      -- the corner potted plants: mostly silhouette, the THIN standee
      -- pool (crown 10/11, leaves 8/9/26/27, pot 24/25)
      prop = { 8, 9, 10, 11, 24, 25, 26, 27 },
      -- the open book on the schoolhouse table: a paper-thin cutout
      -- standing on the pinned tabletop
      cutout = { 70, 71, 86, 87 },
      -- the front-door mat: same $14 water-fallback trap as Red's; flat
      ground = { 4, 20 },
    },

    -- The Pokemon Center lobby.  One tileset serves all eleven Centers
    -- and the Celadon Hotel, and VIRIDIAN_POKECENTER places every tile
    -- the other maps use, so this list -- read off Viridian -- covers
    -- them all.  (The Marts are a DIFFERENT tileset id, MART, that only
    -- shares the atlas image; pins do not carry over.)  Same failure as
    -- the houses: the detector merges the wall-touching counters and
    -- machines into the wall and towers them, and the lounge seat --
    -- which has a PERSON drawn into the tile art -- becomes a monolith
    -- wearing his face.
    POKECENTER = {
      -- the wall band stays one 16px face: striped panels (40), the high
      -- windows (92-95; 94 doubles as the map's warp tile, and pins are
      -- look-only), the pokeball poster (2/3/18/19), and the pillars
      -- (16/41) with their bases (4/5/20/21; 20 is the $14 water-fallback
      -- trap and would recess into a pond lip).  The healing machines'
      -- bodies (72/76/77 console face, 6/22 button panel, 73 light edge,
      -- 7/13 shadowed edge) are ALSO wall: drawn 16px tall against the
      -- band, so wall height is their drawn height and they read as
      -- consoles jutting from it; the near-black screen tiles must be
      -- pinned or the void rule flattens them, and 72 is the $48
      -- water-fallback trap
      wall = { 2, 3, 4, 5, 6, 7, 13, 16, 18, 19, 20, 21, 22, 40, 41,
               72, 73, 76, 77, 92, 93, 94, 95 },
      -- the counters, half a cell high: top band (8) with the nurse's
      -- tray (10), front face (24/25, the game's counterTiles), left end
      -- cap (56) and the Cable Club's light sections (90/91).  8px is
      -- one clean band, so the drawn front panel stands up and the
      -- counter top stays on top; at 12 they read as wall stubs
      counter = { 8, 10, 24, 25, 56, 90, 91,
                  -- and the lounge couch with the man sitting on it.
                  -- Same half-cell box: its bottom row (42/43, the front
                  -- base) stands up as the couch's front, and the three
                  -- rows above it -- cushion (38/39) and the man
                  -- (36/37 head, 52/53 face) -- ride the top face in
                  -- drawn order, each exactly once.  See the note below
                  -- on why he cannot be stood upright.
                  36, 37, 38, 39, 42, 43, 52, 53 },
      -- standing per-pixel props, black-outline segmented: the healing
      -- machines' screen tops (58/59/74/75, drawn above the pinned
      -- bodies so they stand ON them) and the PC (66/70/82/86), which
      -- stands on its pinned desk
      billboard = { 58, 59, 66, 70, 74, 75, 82, 86 },
      -- Why the man on the couch rides the top face instead of standing
      -- up.  He is drawn across two tile rows (skin pixels appear in
      -- rows 8 and 9 and stop dead at the row 9/10 seam), and folding
      -- two rows upright requires both to share a class, which makes the
      -- box two tiles deep -- and a fully folded box repeats its north
      -- row across its whole top face.  So every upright arrangement
      -- puts his head on screen two or three times: as a 16px seat-back
      -- his head lands on the front AND twice on the top; as a 32px
      -- bookcase he becomes a cabinet taller than the room's walls.
      -- Dropping the seat to floor level to clear his face does not help
      -- either, it only moves which copy you see.  He also cannot be a
      -- standee: the drawing has no floor margin, so all three non-black
      -- shades touch the cluster rim and the mask drains 307 of its 420
      -- interior pixels -- 46% of him even segmented alone, because his
      -- skin is the same light shade as the couch behind him.  Riding
      -- the top face is the one arrangement that draws him exactly once.
      -- the PC's desk body, which the PC stands on
      table = { 9, 88 },
      -- the potted plants: bush (32/33/48/49) over pot (34/35/50/51,
      -- 50 is the $32 water-fallback trap).  Standing per-pixel
      -- billboards in the THIN pool, like every other interior plant --
      -- and a pool apart from the sofa, which touches the corner pair
      -- and must stay a separate object.  The bush's light checker
      -- highlights share the floor's shades, so the mask drains some of
      -- them; the standee reads darker than the flat art, which is the
      -- accepted trade for a real plant silhouette
      prop = { 32, 33, 34, 35, 48, 49, 50, 51 },
    },
  },

  -- Buildings whose whole sprite is voxelized band by band (lib/Buildings.lua,
  -- the pipeline in assets/docs/buidling_to_voxel/).  A building is matched by its
  -- exact tile grid -- the drawings are catalogued in assets/docs/buildings/ -- so
  -- every map that places the same art gets the same model: one entry
  -- voxelizes Red's house, Blue's house, Bill's, the Copycat's and the two
  -- Fuchsia houses alike.
  --
  -- Only the BAND TABLE is authored here, because only it needs a human to
  -- read the drawing.  Everything measurable is measured off the pixels:
  -- the silhouette, the taper rate (which IS the roof's slope), the eave
  -- height, and every window and doorway (a non-black region its own black
  -- frame seals off).  Fields:
  --
  --   tiles      the tile-id grid that identifies the building, rows of the
  --              8px tile atlas, north row first
  --   roofRows   how many rows off the top are drawn as TOP-FACING roof;
  --              the rest of the drawing is the facade, seen face-on
  --   roofBack   rows laid along the north rim, one row per voxel of depth
  --   roofFront  rows laid along the south rim (the fascia and eave course)
  --   roofCycle  the row run the middle depth cycles; its length must be
  --              the roof texture's period or the courses will not line up
  --   slab       roof thickness in voxels
  --   frontEave  how far the roof overhangs the facade
  --   ledge      a band that juts two voxels past the walls (an awning),
  --              or nil
  --   seal       sides the drawing runs off rather than closing with its
  --              own outline, as a string of n/s/e/w; the silhouette
  --              flood does not seed there. Only needed by a drawing
  --              trimmed flush to its art -- one whose base course is a
  --              row of brick rather than the black threshold every other
  --              building stands on. Omit it unless the fill says
  --              otherwise: sealing a side the drawing does NOT run off
  --              swallows the terrain beside it.
  --
  -- Nothing here describes the roof's SHAPE, because nothing needs to: the
  -- topmost drawn row of each column is the elevation profile, so a drawn
  -- taper becomes a slope and a roof drawn from straight above comes out
  -- level.  That is why the flat-roofed civic block and its sixteen
  -- relatives -- every Center and Mart, the gyms and gates, the department
  -- store and Silph Co -- share one band table below, differing only in
  -- their tile grids.  The sloped ones fall into three groups just as
  -- cleanly, by the depth of the roof band: 16 rows (Red's house), 32
  -- (Oak's lab) or 64 (the museum).  Before authoring a new one, check
  -- whether its roof band is already pixel for pixel one of those.
  --
  -- assets/docs/buildings/B26 is deliberately absent.  Its drawing has no
  -- black base course -- it ends on a row of light brick -- so the
  -- silhouette flood, which comes in from the border through light pixels,
  -- climbs up through the wall and hollows it out.  Every other building
  -- is sealed by a black threshold row.  Reading it would mean changing
  -- the flood itself, which every model here depends on, for one scenery
  -- placement.
  buildings = {
    OVERWORLD = {
      -- assets/docs/buildings/B07: the two-storey gabled house.  Coursed cap over
      -- a gable wall, an awning with its double black underline, then the
      -- ground floor with the door.  7 placements, Red's and Blue's among
      -- them.  Course rhythm: a dark line every 4 rows.
      {
        id = "gabled_house",
        tiles = {
          {  5,  6,  7,  7,  7,  7,  8,  9 },
          { 21, 22, 23, 23, 23, 23, 24, 25 },
          { 37, 38, 10, 34, 10, 10, 40, 41 },
          { 92, 23, 23, 23, 23, 23, 23, 93 },
          { 15, 34, 11, 12, 10, 10, 34, 31 },
          { 78, 26, 27, 28, 26, 26, 26, 79 },
        },
        roofRows = 16, roofBack = 7, roofFront = 9, roofCycle = { 5, 8 },
        slab = 4, frontEave = 4, ledge = { 24, 31 },
      },

      -- assets/docs/buildings/B31: Oak's lab.  The same architecture with a roof
      -- band twice as deep -- the extra rows are DEPTH, not height, so the
      -- lab is a bigger footprint under the same storey.  Its cross-hatch
      -- roof texture repeats every 8 rows, and it has no awning: the band
      -- that would be one is the roof's own eave course.
      {
        id = "oaks_lab",
        tiles = {
          {  5,  6, 83, 83, 83, 83, 83, 83, 83, 83,  8,  9 },
          { 21, 56, 18, 18, 18, 18, 18, 18, 18, 18, 56, 25 },
          { 21, 56, 18, 18, 18, 18, 18, 18, 18, 18, 56, 25 },
          { 21, 22, 23, 23, 23, 23, 23, 23, 23, 23, 24, 25 },
          { 37, 38, 10, 10, 10, 75, 75, 10, 10, 10, 40, 41 },
          { 15, 34, 34, 34, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 10, 10, 10, 11, 12, 10, 10, 10, 10, 10, 31 },
          { 78, 26, 26, 26, 27, 28, 26, 26, 26, 26, 26, 79 },
        },
        roofRows = 32, roofBack = 7, roofFront = 8, roofCycle = { 5, 12 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B03: the flat-roofed commercial block --
      -- Celadon's diner, hotel, chief's house and prize room, the Bike
      -- Shop, the Fan Club, Mr. Psychic's, the Underground Path entrances.
      -- 15 placements, the most of any voxelized drawing.  The lattice
      -- field is drawn from straight above, so the measured taper is flat
      -- and the whole band is depth under one level roof; the eave course
      -- is the roof's own south rim, lab-style, no awning.  Lattice period
      -- 8, the lab's rhythm again.
      {
        id = "flat_commercial",
        tiles = {
          { 76, 83, 83, 83, 83, 83, 83, 77 },
          { 90, 18, 18, 18, 18, 18, 18, 90 },
          { 90, 18, 18, 18, 18, 18, 18, 90 },
          { 92, 23, 23, 23, 23, 23, 23, 93 },
          { 15, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 75, 11, 12, 75, 75, 75, 31 },
          { 78, 26, 27, 28, 26, 26, 26, 79 },
        },
        roofRows = 32, roofBack = 7, roofFront = 8, roofCycle = { 5, 12 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B05: every Pokemon Center in the game
      -- (Celadon, Cerulean, Cinnabar, Fuchsia, Lavender, Pewter,
      -- Saffron, Vermilion, Viridian, Mt Moon, Rock Tunnel). B03's
      -- block with the POKe sign hung beside the door; the sign is
      -- too wide to be a pane, so it stays flush.
      {
        id = "pokecenter",
        tiles = {
          { 76, 83, 83, 83, 83, 83, 83, 77 },
          { 90, 18, 18, 18, 18, 18, 18, 90 },
          { 90, 18, 18, 18, 18, 18, 18, 90 },
          { 92, 23, 23, 23, 23, 23, 23, 93 },
          { 15, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 75, 11, 12, 66, 67, 75, 31 },
          { 78, 26, 27, 28, 74, 74, 26, 79 },
        },
        roofRows = 32, roofBack = 7, roofFront = 8, roofCycle = { 5, 12 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B06: every Poke Mart (Cerulean,
      -- Cinnabar, Fuchsia, Lavender, Pewter, Saffron, Vermilion,
      -- Viridian). The Center's twin, MART on the sign.
      {
        id = "pokemart",
        tiles = {
          { 76, 83, 83, 83, 83, 83, 83, 77 },
          { 90, 18, 18, 18, 18, 18, 18, 90 },
          { 90, 18, 18, 18, 18, 18, 18, 90 },
          { 92, 23, 23, 23, 23, 23, 23, 93 },
          { 15, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 75, 11, 12, 68, 69, 75, 31 },
          { 78, 26, 27, 28, 74, 74, 26, 79 },
        },
        roofRows = 32, roofBack = 7, roofFront = 8, roofCycle = { 5, 12 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B02: the plain 4x4 block: one window
      -- course over blank brick and no door. 15 placements, scenery
      -- in every city bar the Celadon Mart roof stair.
      {
        id = "flat_block_4x4",
        tiles = {
          { 76, 83, 83, 83, 83, 83, 83, 77 },
          { 90, 18, 18, 18, 18, 18, 18, 90 },
          { 90, 18, 18, 18, 18, 18, 18, 90 },
          { 92, 23, 23, 23, 23, 23, 23, 93 },
          { 15, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 31 },
          { 78, 26, 26, 26, 26, 26, 26, 79 },
        },
        roofRows = 32, roofBack = 7, roofFront = 8, roofCycle = { 5, 12 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B08: the same block two cells deeper,
      -- 6 placements, all scenery.
      {
        id = "flat_block_4x6",
        tiles = {
          { 76, 83, 83, 83, 83, 83, 83, 77 },
          { 90, 18, 18, 18, 18, 18, 18, 90 },
          { 90, 18, 18, 18, 18, 18, 18, 90 },
          { 92, 23, 23, 23, 23, 23, 23, 93 },
          { 15, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 31 },
          { 78, 26, 26, 26, 26, 26, 26, 79 },
        },
        roofRows = 32, roofBack = 7, roofFront = 8, roofCycle = { 5, 12 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B13: the 6x4 scenery block, 4
      -- placements.
      {
        id = "flat_block_6x4",
        tiles = {
          { 76, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 77 },
          { 90, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 90 },
          { 90, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 90 },
          { 92, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 93 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 78, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 79 },
        },
        roofRows = 32, roofBack = 7, roofFront = 8, roofCycle = { 5, 12 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B14: the 6x6 scenery block, 3
      -- placements.
      {
        id = "flat_block_6x6",
        tiles = {
          { 76, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 77 },
          { 90, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 90 },
          { 90, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 90 },
          { 92, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 93 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 78, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 79 },
        },
        roofRows = 32, roofBack = 7, roofFront = 8, roofCycle = { 5, 12 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B27: the 8x4 scenery block, one
      -- placement on Route 11.
      {
        id = "flat_block_8x4",
        tiles = {
          { 76, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 77 },
          { 90, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 90 },
          { 90, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 90 },
          { 92, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 93 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 78, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 79 },
        },
        roofRows = 32, roofBack = 7, roofFront = 8, roofCycle = { 5, 12 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B09: the wide storefront: Celadon's
      -- Game Corner, the Pokemon Mansion, Cinnabar Lab, the Safari
      -- Zone gate and Fuchsia's meeting room.
      {
        id = "game_corner",
        tiles = {
          { 76, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 77 },
          { 90, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 90 },
          { 90, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 90 },
          { 92, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 93 },
          { 15, 10, 10, 10, 10, 75, 75, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 75, 75, 75, 11, 12, 10, 10, 75, 75, 75, 31 },
          { 78, 26, 26, 26, 27, 28, 26, 26, 26, 26, 26, 79 },
        },
        roofRows = 32, roofBack = 7, roofFront = 8, roofCycle = { 5, 12 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B15: Celadon Mansion and the Route 6
      -- and Route 12 gates.
      {
        id = "celadon_mansion",
        tiles = {
          { 76, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 77 },
          { 90, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 90 },
          { 90, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 90 },
          { 92, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 93 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 10, 10, 10, 10, 75, 75, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 75, 75, 75, 11, 12, 10, 10, 75, 75, 75, 31 },
          { 78, 26, 26, 26, 27, 28, 26, 26, 26, 26, 26, 79 },
        },
        roofRows = 32, roofBack = 7, roofFront = 8, roofCycle = { 5, 12 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B18: the Route 2 gate, and the museum's
      -- east entrance beside it in Pewter.  The museum HALL itself is
      -- B24 below, a different drawing with a sloped roof.
      {
        id = "route_2_gate",
        tiles = {
          { 76, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 77 },
          { 90, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 90 },
          { 90, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 90 },
          { 92, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 93 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 75, 11, 12, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 78, 26, 27, 28, 26, 26, 26, 26, 26, 26, 26, 79 },
        },
        roofRows = 32, roofBack = 7, roofFront = 8, roofCycle = { 5, 12 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B29: Fuchsia Gym, the block with GYM
      -- on the sign.
      {
        id = "fuchsia_gym",
        tiles = {
          { 76, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 77 },
          { 90, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 90 },
          { 90, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 90 },
          { 92, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 93 },
          { 15, 10, 10, 10, 34, 47, 63, 34, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 34, 34, 34, 34, 75, 75, 75, 31 },
          { 15, 75, 11, 12, 10, 10, 10, 10, 75, 75, 75, 31 },
          { 78, 26, 27, 28, 26, 26, 26, 26, 26, 26, 26, 79 },
        },
        roofRows = 32, roofBack = 7, roofFront = 8, roofCycle = { 5, 12 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B28: the Route 5 underground-path
      -- gate.
      {
        id = "route_5_gate",
        tiles = {
          { 76, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 77 },
          { 90, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 90 },
          { 90, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 90 },
          { 92, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 93 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 75, 75, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 11, 12, 10, 10, 75, 75, 75, 31 },
          { 78, 26, 26, 26, 26, 26, 26, 26, 27, 28, 26, 26, 26, 26, 26, 79 },
        },
        roofRows = 32, roofBack = 7, roofFront = 8, roofCycle = { 5, 12 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B21: the Route 22 league gate, the
      -- widest of the family at 12 cells.
      {
        id = "route_22_gate",
        tiles = {
          { 76, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 77 },
          { 90, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 90 },
          { 90, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 90 },
          { 92, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 93 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 75, 75, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 11, 12, 10, 10, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 78, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 27, 28, 26, 26, 26, 26, 26, 26, 26, 26, 26, 79 },
        },
        roofRows = 32, roofBack = 7, roofFront = 8, roofCycle = { 5, 12 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B25: the Power Plant.
      {
        id = "power_plant",
        tiles = {
          { 76, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 77 },
          { 90, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 90 },
          { 90, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 90 },
          { 92, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 93 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 75, 75, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 11, 12, 10, 10, 75, 75, 75, 31 },
          { 78, 26, 26, 26, 26, 26, 26, 26, 27, 28, 26, 26, 26, 26, 26, 79 },
        },
        roofRows = 32, roofBack = 7, roofFront = 8, roofCycle = { 5, 12 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B22: Celadon's department store: six
      -- window courses over the MART sign.
      {
        id = "celadon_mart",
        tiles = {
          { 76, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 77 },
          { 90, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 90 },
          { 90, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 90 },
          { 92, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 93 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 10, 10, 10, 10, 75, 75, 10, 10, 75, 75, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 75, 75, 75, 11, 12, 10, 10, 11, 12, 10, 10, 68, 69, 75, 31 },
          { 78, 26, 26, 26, 27, 28, 26, 26, 27, 28, 26, 26, 74, 74, 26, 79 },
        },
        roofRows = 32, roofBack = 7, roofFront = 8, roofCycle = { 5, 12 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B20: Silph Co. Twelve cells of plot
      -- and ten courses of windows under the same roof band, so it
      -- stands as the tallest thing in Kanto.
      {
        id = "silph_co",
        tiles = {
          { 76, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 77 },
          { 90, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 90 },
          { 90, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 90 },
          { 92, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 93 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 10, 10, 10, 10, 75, 75, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 75, 75, 75, 11, 12, 10, 10, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 78, 26, 26, 26, 27, 28, 26, 26, 26, 26, 26, 26, 26, 26, 26, 79 },
        },
        roofRows = 32, roofBack = 7, roofFront = 8, roofCycle = { 5, 12 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B24: the Pewter museum's hall, and the only
      -- building in the family with a SLOPED roof: the same 2:1 taper the
      -- lab and Red's house are drawn with, over a roof band twice the
      -- lab's depth.  The drawing repeats its whole lattice-and-course
      -- motif -- rows 8..31 again at 32..55 -- which is what fixes the
      -- cycle at 24 rather than the bare lattice's 8: the drawing proves
      -- the period.  The last band (rows 56..63) is the roof's fascia,
      -- wider than the wall it covers, so it stays in the roof band and
      -- lands on the south rim.
      {
        id = "museum",
        tiles = {
          {  5,  6, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83,  8,  9 },
          { 21, 56, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 56, 25 },
          { 21, 56, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 56, 25 },
          { 21, 22, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 24, 25 },
          { 21, 56, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 56, 25 },
          { 21, 56, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 56, 25 },
          { 21, 22, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 24, 25 },
          { 37, 38, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 40, 41 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 75, 75, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 11, 12, 10, 10, 75, 75, 75, 31 },
          { 78, 26, 26, 26, 26, 26, 26, 26, 27, 28, 26, 26, 26, 26, 26, 79 },
        },
        roofRows = 64, roofBack = 8, roofFront = 8, roofCycle = { 8, 31 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B10: the gym. Cinnabar, Pewter,
      -- Vermilion and Viridian wear this drawing, and so does the
      -- Fighting Dojo next door to Saffron's. Oak's lab's roof band
      -- exactly, tile for tile, over a facade with GYM on the sign.
      {
        id = "gym",
        tiles = {
          {  5,  6, 83, 83, 83, 83, 83, 83, 83, 83,  8,  9 },
          { 21, 56, 18, 18, 18, 18, 18, 18, 18, 18, 56, 25 },
          { 21, 56, 18, 18, 18, 18, 18, 18, 18, 18, 56, 25 },
          { 21, 22, 23, 23, 23, 23, 23, 23, 23, 23, 24, 25 },
          { 37, 38, 10, 10, 34, 47, 63, 34, 10, 10, 40, 41 },
          { 15, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 31 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 11, 12, 10, 31 },
          { 78, 26, 26, 26, 26, 26, 26, 26, 27, 28, 26, 79 },
        },
        roofRows = 32, roofBack = 7, roofFront = 8, roofCycle = { 5, 12 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B16: the big-city gym: Celadon,
      -- Cerulean and Saffron. Two cells wider than the standard
      -- gym, and it carries the GYM sign twice.
      {
        id = "gym_large",
        tiles = {
          {  5,  6, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83, 83,  8,  9 },
          { 21, 56, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 56, 25 },
          { 21, 56, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 56, 25 },
          { 21, 22, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 23, 24, 25 },
          { 37, 38, 10, 10, 34, 47, 63, 34, 34, 47, 63, 34, 10, 10, 40, 41 },
          { 15, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 34, 31 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 11, 12, 10, 31 },
          { 78, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 27, 28, 26, 79 },
        },
        roofRows = 32, roofBack = 7, roofFront = 8, roofCycle = { 5, 12 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B01: the commonest drawing in the
      -- game at 19 placements, and every one of them scenery: a
      -- gabled block with two window courses and no door. Red's
      -- house's roof band, tile for tile, but no awning under it.
      {
        id = "gabled_block_4x3",
        tiles = {
          {  5,  6,  7,  7,  7,  7,  8,  9 },
          { 21, 22, 23, 23, 23, 23, 24, 25 },
          { 37, 38, 10, 10, 10, 10, 40, 41 },
          { 15, 34, 34, 34, 75, 75, 75, 31 },
          { 15, 10, 10, 10, 10, 10, 10, 31 },
          { 78, 26, 26, 26, 26, 26, 26, 79 },
        },
        roofRows = 16, roofBack = 7, roofFront = 9, roofCycle = { 5, 8 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B04: the little 4x2 cottage, 12
      -- placements and nearly all of them somebody's home: Mr
      -- Fuji's, the Cubone house, Bill's grandpa's, the Name
      -- Rater's, the Viridian school house, the Route 8 underground
      -- path.
      {
        id = "gabled_cottage",
        tiles = {
          {  5,  6,  7,  7,  7,  7,  8,  9 },
          { 21, 22, 23, 23, 23, 23, 24, 25 },
          { 37, 38, 11, 12, 10, 10, 40, 41 },
          { 78, 26, 27, 28, 26, 26, 26, 79 },
        },
        roofRows = 16, roofBack = 7, roofFront = 9, roofCycle = { 5, 8 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B17: the wide 6x2 house: Cerulean's
      -- badge, trade and trashed houses.
      {
        id = "gabled_house_wide",
        tiles = {
          {  5,  6,  7,  7,  7,  7,  7,  7,  7,  7,  8,  9 },
          { 21, 22, 23, 23, 23, 23, 23, 23, 23, 23, 24, 25 },
          { 37, 38, 11, 12, 35, 10, 10, 35, 10, 10, 40, 41 },
          { 78, 26, 27, 28, 26, 26, 26, 26, 26, 26, 26, 79 },
        },
        roofRows = 16, roofBack = 7, roofFront = 9, roofCycle = { 5, 8 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B11: the 6x2 scenery block, 5
      -- placements, no door.
      {
        id = "gabled_block_6x2",
        tiles = {
          {  5,  6,  7,  7,  7,  7,  7,  7,  7,  7,  8,  9 },
          { 21, 22, 23, 23, 23, 23, 23, 23, 23, 23, 24, 25 },
          { 37, 38, 10, 34, 35, 10, 10, 35, 10, 10, 40, 41 },
          { 78, 26, 26, 26, 26, 26, 26, 26, 26, 26, 26, 79 },
        },
        roofRows = 16, roofBack = 7, roofFront = 9, roofCycle = { 5, 8 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B34: the 4x2 scenery block, one
      -- placement in Fuchsia.
      {
        id = "gabled_block_4x2",
        tiles = {
          {  5,  6,  7,  7,  7,  7,  8,  9 },
          { 21, 22, 23, 23, 23, 23, 24, 25 },
          { 37, 38, 10, 34, 10, 10, 40, 41 },
          { 78, 26, 26, 26, 26, 26, 26, 79 },
        },
        roofRows = 16, roofBack = 7, roofFront = 9, roofCycle = { 5, 8 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B33: the Route 5 day care.
      {
        id = "daycare",
        tiles = {
          {  5,  6, 83, 83, 83, 83,  8,  9 },
          { 21, 56, 18, 18, 18, 18, 56, 25 },
          { 21, 56, 18, 18, 18, 18, 56, 25 },
          { 21, 22, 23, 23, 23, 23, 24, 25 },
          { 37, 38, 10, 10, 10, 10, 40, 41 },
          { 15, 34, 34, 34, 34, 34, 34, 31 },
          { 15, 10, 10, 10, 11, 12, 10, 31 },
          { 78, 26, 26, 26, 27, 28, 26, 79 },
        },
        roofRows = 32, roofBack = 7, roofFront = 8, roofCycle = { 5, 12 },
        slab = 4, frontEave = 4, ledge = nil,
      },

      -- assets/docs/buildings/B26: the Route 10 scenery block,
      -- structurally the museum's twin -- Oak's lab's roof band,
      -- and its rows 8..31 repeat at 32..55 exactly as the museum's
      -- do. It needs `seal` because its drawing has no black base
      -- course: it ends on a row of light brick, and unsealed the
      -- flood climbs in from the south border through the mortar
      -- and hollows the wall out (72% of the sprite survives
      -- instead of 95%, in 65 pieces instead of 1).
      {
        id = "gabled_block_6x6",
        tiles = {
          {  5,  6, 83, 83, 83, 83, 83, 83, 83, 83,  8,  9 },
          { 21, 56, 18, 18, 18, 18, 18, 18, 18, 18, 56, 25 },
          { 21, 56, 18, 18, 18, 18, 18, 18, 18, 18, 56, 25 },
          { 21, 22, 23, 23, 23, 23, 23, 23, 23, 23, 24, 25 },
          { 21, 56, 18, 18, 18, 18, 18, 18, 18, 18, 56, 25 },
          { 21, 56, 18, 18, 18, 18, 18, 18, 18, 18, 56, 25 },
          { 21, 22, 23, 23, 23, 23, 23, 23, 23, 23, 24, 25 },
          { 37, 38, 34, 34, 34, 34, 34, 34, 34, 34, 40, 41 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
          { 15, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 31 },
          { 15, 75, 75, 75, 75, 75, 75, 75, 75, 75, 75, 31 },
        },
        roofRows = 64, roofBack = 8, roofFront = 8, roofCycle = { 8, 31 },
        slab = 4, frontEave = 4, ledge = nil, seal = "s",
      },
    },

    FOREST = {
      -- assets/docs/buildings/B12: the Safari Zone rest houses --
      -- Center, East, North, West and the Secret House. A
      -- corrugated roof over a plank facade; its stripe repeats
      -- every 5 rows, not the OVERWORLD lattice's 8.
      {
        id = "safari_rest_house",
        tiles = {
          {  8,  9,  9,  9,  9,  9,  9, 12 },
          { 24, 25, 25, 25, 25, 25, 25, 28 },
          { 40, 41, 42, 43,  1,  1, 41, 44 },
          { 56, 41, 58, 59, 41, 41, 41, 60 },
        },
        roofRows = 17, roofBack = 5, roofFront = 3, roofCycle = { 5, 9 },
        slab = 4, frontEave = 4, ledge = nil,
      },
    },

    PLATEAU = {
      -- assets/docs/buildings/B23: the Victory Road entrance on
      -- Route 23: a long rock face with two barred doors cut into
      -- it. Not a house -- what the roof band reads is the pale top
      -- of the cliff seen from above, and the facade is the
      -- striated rock below it.
      {
        id = "victory_road_gate",
        tiles = {
          { 37, 38,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3,  3, 37, 38 },
          { 40, 41, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 40, 41 },
          { 21, 22, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 46, 47,  3,  3,  3,  3,  3,  3,  3,  3, 46, 47, 15, 15, 15, 15, 15, 15, 21, 22 },
          {  5,  6, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 46, 47,  3,  3,  3,  3,  3,  3,  3,  3, 46, 47, 15, 15, 15, 15, 15, 15,  5,  6 },
          {  5,  6, 15, 15, 15, 15, 15, 15, 11, 12, 15, 15, 15, 15, 15, 15, 46, 47,  3,  3,  3,  3,  3,  3,  3,  3, 46, 47, 11, 12, 15, 15, 15, 15,  5,  6 },
          { 21, 22, 14, 14, 14, 14, 14, 14, 27, 28, 14, 14, 14, 14, 14, 14, 46, 47,  3,  3,  3,  3,  3,  3,  3,  3, 46, 47, 27, 28, 14, 14, 14, 14, 21, 22 },
        },
        roofRows = 16, roofBack = 7, roofFront = 8, roofCycle = { 9, 12 },
        slab = 4, frontEave = 4, ledge = nil,
      },
    },
  },
}
