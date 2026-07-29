-- Figures: a person drawn INTO furniture, cut out by an authored pixel
-- mask and stood up on top of it (TileShape.figures / Structures.
-- buildFigures).  The Pokemon Center's seated man is the case the feature
-- exists for, so this drives the real profile entry over a hand-built
-- copy of the couch block he is drawn in -- POKECENTER blockset entry $08,
-- as every Center places it:
--
--     y=8   36 37 57 11        36/52 west wall strip, 37/53 the MAN,
--     y=9   52 53 60 27        57/60 floor he overhangs east onto,
--     y=10  38 39 54 11        38/39 cushion, 42/43 the couch's base
--     y=11  42 43 26 27
--
-- No love, no GPU and no pixel access: a figure is authored rather than
-- detected, which is exactly what lets it build headless.
--
--   luajit mods/DramaticShapeVoxelMod/tests/voxel_figure_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.harness")

-- ------- the mod namespace (mirrors main.lua's V, minus the mod loader)

local ROOT = os.getenv("DS_MOD_PATH") or "mods/DramaticShapeVoxelMod"
local V = { path = ROOT }

local function chunkFor(rel)
  local f = assert(io.open(ROOT .. "/" .. rel, "rb"), rel .. " is missing")
  local src = f:read("*a")
  f:close()
  return assert(load(src, "@" .. ROOT .. "/" .. rel))
end

local modules, dataFiles = {}, {}
function V.require(name)
  if modules[name] == nil then
    modules[name] = chunkFor("lib/" .. name .. ".lua")(V)
  end
  return modules[name]
end
function V.data(name)
  if dataFiles[name] == nil then
    dataFiles[name] = chunkFor("data/" .. name .. ".lua")(V)
  end
  return dataFiles[name]
end

local TileShape = V.require("TileShape")
local Structures = V.require("Structures")

-- ------- the authored mask parses

local figs = TileShape.figures("POKECENTER")
T.check(type(figs) == "table" and #figs == 1,
  "POKECENTER carries exactly one figure")

local fig = figs[1]
T.eq(fig.w, 2, "the figure is two tiles across")
T.eq(fig.h, 2, "the figure is two tiles tall")
T.eq(fig.n, 128, "the mask claims 128 pixels of the 256 it spans")

-- no holes in him: his tiles' column 7 is the couch's east rule AND the
-- right side of his face, and masking it out by shade slit his cheek open
for ly = 5, 8 do
  T.check(fig.mask[ly * (fig.w * 8) + 7] == true,
    "his cheek is solid at row " .. ly .. " (the column-7 slit)")
end
T.eq(fig.tiles[1], 37, "it starts at the tile his head is drawn in")
T.eq(fig.under[1], 39, "which wears the couch's own cushion once he is off")
T.eq(fig.under[2], 1, "and the floor tiles wear the clean art (57 -> 1)")
T.eq(fig.under[4], 26, "and (60 -> 26)")

-- the mask is one connected figure: an overhang that floats free of him
-- is the failure this feature exists to avoid
local W = fig.w * 8
local seen, first = {}, nil
for i in pairs(fig.mask) do first = first or i end
local stack, n = { first }, 0
seen[first] = true
while #stack > 0 do
  local i = table.remove(stack)
  n = n + 1
  local x, y = i % W, math.floor(i / W)
  for dy = -1, 1 do
    for dx = -1, 1 do
      local nx, ny = x + dx, y + dy
      local ni = ny * W + nx
      if (dx ~= 0 or dy ~= 0) and nx >= 0 and nx < W
         and fig.mask[ni] and not seen[ni] then
        seen[ni] = true
        stack[#stack + 1] = ni
      end
    end
  end
end
T.eq(n, fig.n, "the mask is a single connected figure")

-- ------- the couch block, as the Centers place it

local function keyOf(tx, ty) return (ty + 64) * 4096 + (tx + 64) end

local COUNTER = { class = "counter", h = 8, art = "upright",
                  flat = false, authored = true }
local GROUND = { class = "ground", h = 0, art = "flat",
                 flat = true, authored = false }

local BLOCK = { 36, 37, 57, 11,
                52, 53, 60, 27,
                38, 39, 54, 11,
                42, 43, 26, 27 }
local COUCH = { [36] = true, [37] = true, [38] = true, [39] = true,
                [42] = true, [43] = true, [52] = true, [53] = true }

local function scene()
  local S = { shapeAt = {}, tileAt = {}, objectQuads = {}, skip = {},
              ground = {}, runs = {} }
  for i = 1, 16 do
    local tx, ty = (i - 1) % 4, 8 + math.floor((i - 1) / 4)
    local tile = BLOCK[i]
    S.tileAt[keyOf(tx, ty)] = tile
    S.shapeAt[keyOf(tx, ty)] = COUCH[tile] and COUNTER or GROUND
  end
  return S
end

-- collision is per 16x16 cell: the couch's cell is blocked (he is drawn
-- sitting on it), the floor cell east of it is walkable
local map = {
  tileset = { id = "POKECENTER", tilesPerRow = 16,
              imageWidth = 128, imageHeight = 48 },
  isWalkableCell = function(_, cx) return cx >= 1 end,
}

-- ------- he comes off the couch

local S = scene()
Structures.buildFigures(S, map, 0, 3, 8, 11)

T.check(#S.objectQuads > 0, "the figure built geometry")

T.eq(S.tileAt[keyOf(1, 8)], 39, "his head tile now wears the cushion")
T.eq(S.tileAt[keyOf(1, 9)], 39, "his body tile too")
T.eq(S.tileAt[keyOf(2, 8)], 1, "the floor he overhung is clean floor again")
T.eq(S.tileAt[keyOf(2, 9)], 26, "both rows of it")
T.eq(S.tileAt[keyOf(0, 8)], 36, "the west wall strip beside him is untouched")
T.eq(S.tileAt[keyOf(1, 10)], 39, "and the couch's own cushion row is too")

-- the couch keeps its box: a figure changes ART, never class
T.eq(S.shapeAt[keyOf(1, 8)].class, "counter",
  "his tiles are still the couch's half-cell box")
T.check(S.skip[keyOf(1, 8)] ~= true,
  "and are not skipped -- the couch still renders there")

-- ------- where he stands

local minX, maxX, minY, maxY, minZ, maxZ
for _, q in ipairs(S.objectQuads) do
  for c = 1, 4 do
    local p = q[c]
    minX = math.min(minX or p[1], p[1]); maxX = math.max(maxX or p[1], p[1])
    minY = math.min(minY or p[2], p[2]); maxY = math.max(maxY or p[2], p[2])
    minZ = math.min(minZ or p[3], p[3]); maxZ = math.max(maxZ or p[3], p[3])
  end
end

T.eq(minY, 8, "his feet are on the couch's top face, not the floor")
T.eq(maxY, 24, "and he stands his drawn 16px tall from there")
T.eq(minX, 8, "he starts at the tile column he is drawn in")
T.eq(maxX, 18, "and reaches his hair's overhang, two pixels east of it")
T.eq(maxZ - minZ, 1, "a flat card, one voxel deep, like the walking NPCs")

-- and he stands in the depth band of the row he is DRAWN in -- the couch's
-- northern cell (tile row 9 spans z 72..80), not shifted onto its southern
-- half the way a supported prop is
T.check(minZ >= 72 and maxZ <= 80,
  "he stands on his own cell, not the couch's southern half")

-- the cushion wedge under his legs stayed with the couch: his lowest row
-- is his foot alone, not the whole tile width
local footMinX
for _, q in ipairs(S.objectQuads) do
  for c = 1, 4 do
    if q[c][2] == 8 then footMinX = math.min(footMinX or q[c][1], q[c][1]) end
  end
end
T.eq(footMinX, 14, "the couch cushion beside his foot was left behind")

-- ------- a map that does not draw him builds nothing

local other = scene()
other.tileAt[keyOf(1, 8)] = 40
Structures.buildFigures(other, map, 0, 3, 8, 11)
T.eq(#other.objectQuads, 0, "no match, no figure")
T.eq(other.tileAt[keyOf(2, 8)], 57, "and nothing repainted")

-- ------- and it never fires twice on the same drawing

local twice = scene()
Structures.buildFigures(twice, map, 0, 3, 8, 11)
local once = #twice.objectQuads
Structures.buildFigures(twice, map, 0, 3, 8, 11)
T.eq(#twice.objectQuads, once,
  "the repaint replaces the pattern, so a rescan cannot match it again")

T.finish("DRAMATIC_SHAPE figures")
