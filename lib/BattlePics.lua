-- Overworld battles: giving a battle pic its paper back.
--
-- Gen 1 battle pics are two-bit art whose lightest shade is WHITE, and the
-- engine's decoded PNGs key that shade to alpha 0 -- which was free, because
-- the field behind them was white too. A transparent belly on a white page
-- is a white belly.
--
-- Put a route behind it and the belly is grass. Charizard's chest, the whites
-- of every eye, the highlight down a Pikachu's cheek: all of it turns into a
-- hole with the world showing through, and the mon reads as a stencil.
--
-- So the paper is put back, and only where the paper was. Which pixels those
-- are is the whole problem, and it has to be ANSWERED rather than looked up:
-- the hardware drew the mon's white belly and the white field behind it with
-- the same shade, the decoder keyed both to the same alpha, and nothing in the
-- image says which was which. There is no distinction to recover; there is one
-- to draw.
--
-- Two rules, and a pixel filled by either is paper:
--
--   ENCLOSED   the transparent region outside the figure is flood-filled from
--              the border, and anything transparent the flood cannot reach is
--              a hole the artwork closes on all sides.
--
--   UNDER THE  anything transparent with ink somewhere to its left AND to its
--   DRAWING    right AND above it.
--
-- The first is exact and catches almost nothing: Gen 1 pics are open figures,
-- and a belly reaches the border through the gap between two legs. Read across
-- all 305 of this game's battle pics, it fills an enclosed hole in none of them
-- -- so on its own it left every mon a stencil, which is the bug this file
-- exists to fix and did not.
--
-- The second is the one that does the work: paper is what the figure is drawn
-- OVER, and a pixel with the drawing to either side of it and over it is under
-- the drawing. The sky above a pair of ears has nothing over it and stays sky;
-- the ground beside a foot has nothing on one side of it and stays ground.
--
-- The asymmetry is the whole trick and it is not arbitrary. Look BELOW a pixel
-- and the question has no answer, because a battle pic is CROPPED FLUSH AT THE
-- FEET -- bottom-aligned in its slot, with the margin all at the top. Half of
-- any mon's belly has bare frame edge under it and nothing else, which is why
-- requiring ink below left a clean vertical channel of world showing through
-- the middle of a Clefairy. And below cannot be accepted on its own either, or
-- the entire sky over a mon's head fills in: it has the mon under it.
--
-- It is a heuristic and it is allowed to be one. What it fills that hardware
-- would not have distinguished is a deep notch -- the gap between two legs,
-- with a belly over it -- and the hardware drew white there too, so that is
-- the pixel the artist saw.
--
-- The silhouette is untouched either way, so the mon still cuts cleanly
-- against the world; only its insides stop being see-through.
--
-- Read back off the GPU rather than off the asset, deliberately. What comes
-- back is the pic the engine actually decided to draw -- species palette,
-- forced-mono rebuild, shiny recolour, a mod's replacement art -- so this
-- needs to know nothing about how any of that was arrived at. Once per pic
-- per session, cached on the image itself.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local BattlePics = {}

-- Cached by the image the engine handed over. Weak keys, so a pic that goes
-- out of scope takes its filled twin with it rather than pinning a texture
-- for the session.
local cache = setmetatable({}, { __mode = "k" })

-- What an enclosed hole is filled with. White, because white is what the
-- battle field was: this restores the pixel the artist drew and the engine
-- then keyed away, it does not invent a new one.
BattlePics.FILL = { 1, 1, 1, 1 }

-- Anything at or under this alpha counts as keyed-out rather than drawn.
local CUT = 0.5

-- Read the pixels the engine would actually blit. A LOVE Image does not hand
-- its data back, so it is drawn into a canvas of its own size and the canvas
-- is read -- which is also what makes this work for every path that produces
-- a pic, without knowing which one produced this one.
local function readBack(img)
  local w, h = img:getDimensions()
  if w <= 0 or h <= 0 then return nil end
  local prevCanvas = love.graphics.getCanvas()
  local prevBlend, prevAlpha = love.graphics.getBlendMode()
  local prevR, prevG, prevB, prevA = love.graphics.getColor()
  local data = nil
  local ok = pcall(function()
    local canvas = love.graphics.newCanvas(w, h)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setBlendMode("replace", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, 0, 0)
    love.graphics.setCanvas()
    data = canvas:newImageData()
    if canvas.release then pcall(canvas.release, canvas) end
  end)
  if prevCanvas then
    love.graphics.setCanvas(prevCanvas)
  else
    love.graphics.setCanvas()
  end
  love.graphics.setBlendMode(prevBlend or "alpha", prevAlpha)
  love.graphics.setColor(prevR or 1, prevG or 1, prevB or 1, prevA or 1)
  return ok and data or nil
end

-- Mark every transparent pixel reachable from the border. That set is the
-- OUTSIDE; everything transparent it does not reach is an enclosed hole.
--
-- An explicit stack rather than recursion: a 56x56 pic is three thousand
-- pixels and a keyed-out background is most of them, which is a deeper call
-- chain than is worth risking for no gain.
local function markOutside(data, w, h)
  local outside = {}
  local stack, top = {}, 0
  local function push(x, y)
    if x < 0 or y < 0 or x >= w or y >= h then return end
    local key = y * w + x
    if outside[key] then return end
    local _, _, _, a = data:getPixel(x, y)
    if a > CUT then return end
    outside[key] = true
    top = top + 1
    stack[top] = key
  end
  for x = 0, w - 1 do
    push(x, 0)
    push(x, h - 1)
  end
  for y = 0, h - 1 do
    push(0, y)
    push(w - 1, y)
  end
  while top > 0 do
    local key = stack[top]
    top = top - 1
    local x, y = key % w, math.floor(key / w)
    push(x - 1, y)
    push(x + 1, y)
    push(x, y - 1)
    push(x, y + 1)
  end
  return outside
end

-- Mark every transparent pixel with ink to its left, to its right and above.
--
-- Three running scans rather than three searches per pixel: sweeping each row
-- left to right carries "has there been ink yet" along with it, the same sweep
-- the other way, and one down the columns. Three passes over the image however
-- big the figure is.
local function markUnderDrawing(data, w, h)
  local ink = {}
  for y = 0, h - 1 do
    local row = y * w
    for x = 0, w - 1 do
      local _, _, _, a = data:getPixel(x, y)
      if a > CUT then ink[row + x] = true end
    end
  end

  local left, right, above = {}, {}, {}
  for y = 0, h - 1 do
    local row, seen = y * w, false
    for x = 0, w - 1 do
      left[row + x] = seen
      seen = seen or ink[row + x] or false
    end
    seen = false
    for x = w - 1, 0, -1 do
      right[row + x] = seen
      seen = seen or ink[row + x] or false
    end
  end
  for x = 0, w - 1 do
    local seen = false
    for y = 0, h - 1 do
      above[y * w + x] = seen
      seen = seen or ink[y * w + x] or false
    end
  end

  local under = {}
  for key = 0, w * h - 1 do
    if not ink[key] and left[key] and right[key] and above[key] then
      under[key] = true
    end
  end
  return under
end

-- The pic with its enclosed holes filled, or the pic itself when that could
-- not be done (no pixel access, a driver that refused the readback). Never
-- nil for a non-nil argument: a caller must always have something to draw.
function BattlePics.filled(img)
  if not img then return img end
  local hit = cache[img]
  if hit ~= nil then return hit or img end

  local made = nil
  local ok = pcall(function()
    local data = readBack(img)
    if not data then return end
    local w, h = data:getDimensions()
    local outside = markOutside(data, w, h)
    local under = markUnderDrawing(data, w, h)
    local fill = BattlePics.FILL
    local changed = false
    for y = 0, h - 1 do
      local row = y * w
      for x = 0, w - 1 do
        if not outside[row + x] or under[row + x] then
          local _, _, _, a = data:getPixel(x, y)
          if a <= CUT then
            data:setPixel(x, y, fill[1], fill[2], fill[3], fill[4])
            changed = true
          end
        end
      end
    end
    -- nothing enclosed: hand the original back rather than a copy of it
    if not changed then return end
    local out = love.graphics.newImage(data)
    out:setFilter("nearest", "nearest")
    made = out
  end)

  cache[img] = (ok and made) or false
  return made or img
end

function BattlePics.invalidate()
  cache = setmetatable({}, { __mode = "k" })
end

return BattlePics
