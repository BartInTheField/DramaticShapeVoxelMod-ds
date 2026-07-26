-- Voxel world mode: characters as forward-facing sprite billboards WITH
-- relief.
--
-- Each entity renders as its CURRENT 2D sprite frame voxelized into a
-- contoured slab: opaque pixels become geometry (the sheets carry real
-- alpha, so transparency is exact), and each ROW's thickness comes from
-- the sheet's own SIDE-VIEW silhouette at that row -- the same
-- match-the-pixel-profile idea the tree lathe uses, applied along depth.
-- The cap brim stays thin, the head rounds back deep, shoulders step out
-- past the neck, feet taper: viewed at tilt angles the top rims trace the
-- character's real profile instead of a uniform one-voxel wafer. Rows are
-- centered on the sprite plane, so the front face relief is symmetric
-- with the back.
--
-- Meshes are built per (sheet, frame) and cached; right-facing and the
-- alternating walk step are matrix mirrors, not extra meshes. UVs point
-- into the live sheet image, so RED++ OBP bakes, SGB palette bakes and
-- sprite-replacing mods all texture the slab with no rebuild.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local Assets = require("src.render.Assets")
local Voxel3D = V.require("Voxel3D")

local SpriteBillboards = {}

-- depth = side-view span * SCALE, clamped -- full span would make heads
-- as deep as the sprite is wide, which reads bulbous at these sizes
SpriteBillboards.DEPTH_SCALE = 0.5
SpriteBillboards.MIN_DEPTH = 2
SpriteBillboards.MAX_DEPTH = 8

local meshes = {}

local function build(def, frame)
  local ok, id = pcall(Assets.imageData, def.image)
  if not (ok and id and id.getPixel) then return nil end
  local iw, ih = id:getDimensions()
  local frames = math.floor(ih / 16)
  local fy = frame * 16
  if fy + 16 > ih then fy = 0 end

  local function opaqueAt(fbase, x, y)
    if x < 0 or x > 15 or y < 0 or y > 15 then return false end
    local _, _, _, a = id:getPixel(x, fbase + y)
    return a > 0
  end
  local function opaque(x, y) return opaqueAt(fy, x, y) end

  -- Per-row depth from the sheet's side view: the LEFT-facing frame that
  -- matches this frame's pose (stand 2 / walk 5, data/sprites/facings.asm
  -- layout). Sheets without one (items, boulders) stay uniform.
  local depth = {}
  do
    local sideFrame = nil
    if frames >= 6 then
      sideFrame = frame >= 3 and 5 or 2
    elseif frames >= 3 then
      sideFrame = 2
    end
    local sy = sideFrame and sideFrame * 16
    for iy = 0, 15 do
      local d = 3
      if sy then
        local lo, hi = nil, nil
        for ix = 0, 15 do
          if opaqueAt(sy, ix, iy) then
            lo = lo or ix
            hi = ix
          end
        end
        if lo then
          d = (hi - lo + 1) * SpriteBillboards.DEPTH_SCALE
          d = math.max(SpriteBillboards.MIN_DEPTH,
                       math.min(SpriteBillboards.MAX_DEPTH, d))
        end
      end
      depth[iy] = d
    end
  end

  local verts, indices = {}, {}
  local function quad(c, uv, shade)
    for i = 1, 4 do
      verts[#verts + 1] = { c[i][1], c[i][2], c[i][3],
                            uv[i][1], uv[i][2], shade }
    end
    Voxel3D.pushQuad(indices, #verts / 4 - 1)
  end
  local function uvx(x) return x / iw end
  local function uvy(y) return (fy + y) / ih end

  -- horizontal runs of opaque pixels; each row is a box slice as deep as
  -- its side profile, centered on the sprite plane (z = 0)
  for iy = 0, 15 do
    local yT, yB = 16 - iy, 15 - iy
    local zF, zB = depth[iy] / 2, -depth[iy] / 2
    local ix = 0
    while ix < 16 do
      if opaque(ix, iy) then
        local ix2 = ix
        while ix2 + 1 < 16 and opaque(ix2 + 1, iy) do ix2 = ix2 + 1 end
        local u0, u1 = uvx(ix + 0.02), uvx(ix2 + 0.98)
        local v0, v1 = uvy(iy + 0.02), uvy(iy + 0.98)
        quad({ { ix, yB, zF }, { ix2 + 1, yB, zF },
               { ix2 + 1, yT, zF }, { ix, yT, zF } },
             { { u0, v1 }, { u1, v1 }, { u1, v0 }, { u0, v0 } }, 1)
        quad({ { ix2 + 1, yB, zB }, { ix, yB, zB },
               { ix, yT, zB }, { ix2 + 1, yT, zB } },
             { { u1, v1 }, { u0, v1 }, { u0, v0 }, { u1, v0 } }, 0.7)
        -- rims: exposed where the neighbouring row lacks the pixel OR is
        -- shallower than this row (the step of the depth profile); a full
        -- row-depth quad is safe either way -- any overlap is sandwiched
        -- inside the thicker slice and never visible
        for px = ix, ix2 do
          local pu0, pu1 = uvx(px + 0.1), uvx(px + 0.9)
          local pv = uvy(iy + 0.5)
          if not opaque(px, iy - 1) or depth[iy - 1 >= 0 and iy - 1 or 0]
             < depth[iy] then
            quad({ { px, yT, zB }, { px + 1, yT, zB },
                   { px + 1, yT, zF }, { px, yT, zF } },
                 { { pu0, pv }, { pu1, pv }, { pu1, pv }, { pu0, pv } }, 0.9)
          end
          if yB > 0 and (not opaque(px, iy + 1)
                         or depth[iy + 1 <= 15 and iy + 1 or 15]
                            < depth[iy]) then
            quad({ { px + 1, yB, zB }, { px, yB, zB },
                   { px, yB, zF }, { px + 1, yB, zF } },
                 { { pu1, pv }, { pu0, pv }, { pu0, pv }, { pu1, pv } }, 0.55)
          end
        end
        local lv = { uvx(ix + 0.5), uvy(iy + 0.5) }
        if not opaque(ix - 1, iy) then
          quad({ { ix, yB, zB }, { ix, yB, zF },
                 { ix, yT, zF }, { ix, yT, zB } },
               { lv, lv, lv, lv }, 0.78)
        end
        if not opaque(ix2 + 1, iy) then
          quad({ { ix2 + 1, yB, zF }, { ix2 + 1, yB, zB },
                 { ix2 + 1, yT, zB }, { ix2 + 1, yT, zF } },
               { lv, lv, lv, lv }, 0.78)
        end
        ix = ix2 + 1
      else
        ix = ix + 1
      end
    end
  end
  return Voxel3D.newMesh(verts, indices)
end

-- The slab mesh for one (sprite def, frame index), or nil (headless / no
-- pixel access), cached like every other derived GPU object.
function SpriteBillboards.mesh(def, frame)
  local key = def.image .. "#" .. frame
  if meshes[key] == nil then
    local ok, m = pcall(build, def, frame)
    meshes[key] = (ok and m) or false
  end
  return meshes[key] or nil
end

-- One flat 16x16 quad UV-mapped to a whole frame, for the drop-shadow
-- pass: the shader's alpha discard cuts the sprite's silhouette out of it,
-- so a single quad casts the exact outline with no self-overlap to
-- double-darken. Needs only the sheet dimensions, not pixel access.
local function buildShadowQuad(def, frame)
  local ok, img = pcall(Assets.image, def.image)
  if not (ok and img) then return nil end
  local iw, ih = img:getDimensions()
  local fy = frame * 16
  if fy + 16 > ih then fy = 0 end
  local u0, u1 = 0.02 / iw, (16 - 0.02) / iw
  local v0, v1 = (fy + 0.05) / ih, (fy + 15.95) / ih
  local verts = {
    { 0, 0, 0, u0, v1, 1 }, { 16, 0, 0, u1, v1, 1 },
    { 16, 16, 0, u1, v0, 1 }, { 0, 16, 0, u0, v0, 1 },
  }
  local indices = {}
  Voxel3D.pushQuad(indices, 0)
  return Voxel3D.newMesh(verts, indices)
end

function SpriteBillboards.shadowQuad(def, frame)
  local key = def.image .. "#s" .. frame
  if meshes[key] == nil then
    local ok, m = pcall(buildShadowQuad, def, frame)
    meshes[key] = (ok and m) or false
  end
  return meshes[key] or nil
end

function SpriteBillboards.invalidate()
  meshes = {}
end

Assets.register(SpriteBillboards.invalidate)

return SpriteBillboards
