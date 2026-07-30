-- The sky, generated rather than shipped.
--
-- The overworld's, on every VOXEL rung. Wherever the diorama is drawn the void
-- behind it is sky rather than a black plate: at 75 degrees the horizon is
-- genuinely in frame and the bands run down to meet it, and at the steeper rungs
-- the void that shows is the ground running out past the map edge, which gets
-- the same sky above the same haze. A battle's placed camera keeps the flat fill
-- it has always had -- its horizon is above the frame and its look is not this
-- rung's to change.
--
-- THE RECIPE is the 8-bit skybox one: a short palette of blues painted as flat
-- horizontal bands, deepest overhead, with a CHECKERBOARD of the next band
-- dithered into the bottom of each one. Alternating two colours on a pixel grid
-- is how a machine with four colours to a palette got a fifth, sixth and seventh
-- out of them, and it is what keeps four bands reading as a gradient rather than
-- as four stripes. No clouds, nothing moving.
--
-- NOTHING IS RESAMPLED, which is the whole of why it is drawn this way. There is
-- no baked 160x144 picture scaled up to the window, no downsized buffer blown
-- back up, no texture of any kind: one full-region rectangle through a shader
-- that answers every pixel from its own canvas coordinate. A pixel of sky is
-- computed at the size it is displayed at, so there is nothing for a filter to
-- soften and nothing to go stale when the window or the zoom changes.
--
-- THE PIXEL GRID follows the zoom for the same reason. Bands and dither cells
-- are measured in DIORAMA pixels -- the pass's own pixels-per-world-pixel, handed
-- in fresh every frame -- so a chunky sky at 4x is a chunky sky at 12x, band
-- edges land on the same grid the world's own texels do, and a ZOOM keypress is
-- reflected in the frame that follows it rather than whenever something else
-- happened to rebuild.
--
-- PALETTE ORDER, which is easy to get wrong. Stored LIGHTEST FIRST, because that
-- is shade order: a display mode transforms a four-colour palette by replacing it
-- outright (PaletteFX.effectiveColors hands back GRAYS or CLASSIC), and those are
-- written light to dark. So the sky reads the list backwards -- shade 4 overhead,
-- shade 1 at the horizon -- and GRAY gets four greys the right way up for
-- nothing.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local PaletteFX = require("src.render.PaletteFX")

local unpack = table.unpack or unpack

local Sky = {}

-- Lightest first. Every channel is a multiple of 8, which is where a five-bit
-- GBC channel lands: these are colours the hardware could actually have shown,
-- not blues picked off a 24-bit colour wheel.
Sky.PALETTE = {
  { 144, 192, 248 },   -- shade 1: pale, at the horizon
  { 104, 160, 240 },
  { 72, 128, 224 },
  { 48, 96, 200 },     -- shade 4: deep, overhead
}

-- The shader carries a fixed-size array, because a GLSL uniform array is a fixed
-- size; four is also what a display mode has to give (it substitutes a palette),
-- so this is the ceiling on the palette above rather than an arbitrary cap.
Sky.MAX_BANDS = 4

-- The checkerboard between bands. DITHER_START is how far down a band it begins,
-- as a fraction of that band: lower is a wider blend, and 1 switches it off. 0.6
-- leaves the top of each band flat -- a band dithered all the way through reads
-- as one averaged colour instead of as a step with a soft bottom edge.
Sky.DITHER = true
Sky.DITHER_START = 0.6

-- How much of the frame the bands cover when the horizon is NOT in it, as a
-- fraction of the canvas height.
--
-- At the steeper rungs the camera looks down far enough that the ground plane's
-- vanishing line is above the top edge -- there is no horizon to hang the pale
-- end on, but there is still void up there where the map runs out, and it should
-- read as sky. So the bands take the same slice of the frame the top rung's own
-- horizon gives them, which keeps the sky looking like one sky across the whole
-- ladder instead of changing character rung by rung.
Sky.SPAN = 0.23

-- ------- the bands
--
-- Top first, each a { r, g, b } in 0..1, as the display mode has them.
--
-- Memoised, because this runs once a frame and the answer only moves when the
-- mode does.
local cache = { bands = nil, key = {} }

function Sky.bands()
  local shades = PaletteFX.effectiveColors(Sky.PALETTE) or Sky.PALETTE
  local n = math.min(#shades, #Sky.PALETTE, Sky.MAX_BANDS)
  local key, k = cache.key, 0
  local same = cache.bands ~= nil and #cache.bands == n
  for i = 1, n do
    local c = shades[i]
    for ch = 1, 3 do
      k = k + 1
      if key[k] ~= c[ch] then same = false end
      key[k] = c[ch]
    end
  end
  if same then return cache.bands end

  local bands = {}
  for i = 1, n do
    -- backwards: the palette's darkest rung is the top band
    local c = shades[n - i + 1]
    bands[i] = { c[1] / 255, c[2] / 255, c[3] / 255 }
  end
  cache.bands = bands
  return bands
end

-- Put the sky onto a flat descriptor: the bands to paint, plus the flat fill
-- replaced by the palest of them. That fill is what the caller CLEARS to, so
-- making it the bottom band's own colour means the haze below the sky and the
-- bottom of the sky are one colour -- the join has no seam, and a frame that
-- cannot paint the bands is a hazy sky rather than a wrong one.
--
-- Mutates the descriptor, which is a fresh table per frame from its caller.
function Sky.dress(sky)
  local bands = Sky.bands()
  local haze = bands and bands[#bands]
  if not (sky and haze) then return sky end
  sky[1], sky[2], sky[3] = haze[1], haze[2], haze[3]
  sky.bands = bands
  return sky
end

-- Where the sky's bottom edge goes, in canvas pixels: the camera's own horizon
-- when that is in frame, and SPAN of the frame when it is not (see SPAN). nil
-- when there is no room for any of it.
function Sky.region(h, horizonY)
  if not (h and h > 0) then return nil end
  local edge = horizonY
  if not (edge and edge > 0) then edge = h * Sky.SPAN end
  edge = math.min(edge, h)
  if edge < 1 then return nil end
  return edge
end

-- ------- the pass
--
-- One rectangle, one shader, no texture. Every pixel answers for itself from its
-- canvas coordinate, so the sky is drawn at exactly the resolution it is
-- displayed at -- there is no image being scaled and so nothing to be soft.
--
-- `cell` quantises BOTH the band edges and the dither: the y a pixel is judged
-- by is the top of its own cell row, so a whole cell row is one colour and every
-- edge in the sky lands on the diorama's pixel grid.
local SHADER_SRC = [[
#define MAXB %d
uniform vec3 bands[MAXB];
uniform int count;
uniform float edge;     // the sky's bottom, in canvas pixels
uniform float cell;     // the diorama's pixel size, in canvas pixels
uniform float start;    // where the checker begins inside a band
uniform float alpha;

// Indexed through a loop counter, which every GLSL ES compiler accepts for a
// uniform array; a bare bands[idx] is not portable.
vec3 bandAt(int idx) {
  vec3 c = bands[0];
  for (int i = 1; i < MAXB; i++) {
    if (i == idx) { c = bands[i]; }
  }
  return c;
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
  float n = float(count);
  float row = floor(sc.y / cell) * cell;              // top of this cell row
  float pos = clamp(row / max(edge, 1.0), 0.0, 0.999999) * n;
  float base = floor(pos);
  int idx = int(base);
  vec3 c = bandAt(idx);
  if (idx < count - 1 && (pos - base) > start) {
    float parity = mod(floor(sc.x / cell) + floor(sc.y / cell), 2.0);
    if (parity < 0.5) { c = bandAt(idx + 1); }
  }
  return vec4(c, alpha);
}
]]

local shader = nil            -- nil = untried, false = unavailable

local function getShader()
  if shader == nil then
    shader = false
    if love.graphics and love.graphics.newShader then
      local ok, sh = pcall(love.graphics.newShader,
                           SHADER_SRC:format(Sky.MAX_BANDS))
      if ok and sh then
        shader = sh
      elseif V and V.mod and V.mod.log then
        -- once, and only where it can be read: the fallback below is a sky
        -- without its dither, which is easy to look at and impossible to
        -- diagnose without this line
        V.mod.log:warn("sky shader did not compile: %s -- the bands draw flat, "
                       .. "with no dither between them", tostring(sh))
      end
    end
  end
  return shader or nil
end

Sky._getShader = getShader        -- named for the suite

-- The flat fallback: the same bands as solid rectangles, no checker, on the same
-- quantised edges. For a driver that could not compile the shader -- which is
-- also every headless run.
local function paintFlat(w, h, bands, edge, alpha, cell)
  local g = love.graphics
  local n = #bands
  local prev = 0
  for i = 1, n do
    local cut = (i == n) and math.min(h, math.ceil(edge))
                         or math.floor(i / n * edge / cell + 0.5) * cell
    cut = math.max(prev, math.min(cut, math.min(h, math.ceil(edge))))
    if cut > prev then
      local c = bands[i]
      g.setColor(c[1], c[2], c[3], alpha)
      g.rectangle("fill", 0, prev, w, cut - prev)
    end
    prev = cut
  end
end

-- Paint the sky into the bound canvas, filling it from the top edge down to
-- `horizonY` (or to SPAN of the frame when the horizon is out of it).
--
-- `cell` is the diorama's pixel size in canvas pixels -- the pass's own
-- pixels-per-world-pixel, handed in every frame so a zoom lands immediately.
--
-- Returns false when there is nothing to paint, in which case the caller's flat
-- fill is the whole sky. That fill is the palest band, so a frame that declines
-- this looks like a hazy day rather than like a bug.
function Sky.paint(w, h, sky, horizonY, cell)
  local bands = sky and sky.bands
  if not (bands and bands[1]) then return false end
  if not (w and h and w > 0 and h > 0) then return false end
  local g = love.graphics
  if not (g and g.rectangle) then return false end
  local edge = Sky.region(h, horizonY)
  if not edge then return false end
  local alpha = sky[4] or 1
  cell = math.max(1, math.floor((cell or 1) + 0.5))

  -- State to put aside. The scene's shader is one, and the blend mode another --
  -- a pass that left "replace" behind would make the fade-in strength meaningless
  -- -- but the DEPTH MODE is the one that would break the frame: a rectangle
  -- drawn under the pass's own ("lequal", true) stamps itself across the depth
  -- buffer at the near plane and hides the entire world behind the sky.
  local prevShader = g.getShader and g.getShader() or nil
  local cmp, write
  if g.getDepthMode then cmp, write = g.getDepthMode() end
  if g.setDepthMode then g.setDepthMode("always", false) end
  local blend, blendAlpha
  if g.getBlendMode then blend, blendAlpha = g.getBlendMode() end
  if g.setBlendMode then g.setBlendMode("alpha") end

  local sh = getShader()
  if sh then
    local sent = pcall(function()
      -- one send per band would be one uniform lookup per band; the array takes
      -- them all at once, and it must be the LAST argument or Lua truncates the
      -- unpack to a single value
      sh:send("bands", unpack(bands))
      sh:send("count", #bands)
      sh:send("edge", edge)
      sh:send("cell", cell)
      sh:send("start", Sky.DITHER and Sky.DITHER_START or 2)
      sh:send("alpha", alpha)
    end)
    if sent then
      g.setShader(sh)
      g.setColor(1, 1, 1, 1)
      g.rectangle("fill", 0, 0, w, math.min(h, math.ceil(edge)))
      g.setShader()
    else
      sh = nil
    end
  end
  if not sh then paintFlat(w, h, bands, edge, alpha, cell) end
  g.setColor(1, 1, 1, 1)

  if g.setBlendMode and blend then g.setBlendMode(blend, blendAlpha) end
  if g.setDepthMode then g.setDepthMode(cmp or "always", write or false) end
  if prevShader and g.setShader then g.setShader(prevShader) end
  return true
end

-- Drop the compiled shader (window resize, hot reload), so a re-created graphics
-- context builds a new one instead of drawing with a handle from the old.
function Sky.invalidate()
  shader = nil
end

return Sky
