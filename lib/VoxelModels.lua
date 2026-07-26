-- Voxel world mode: character models.
--
-- Loads the face lists tools/build_voxels.py carves into this mod's own
-- assets/voxels/<name>.lua and turns them into meshes. A face carries the
-- sheet pixel it samples rather than a baked color, so a model textures
-- from the LIVE sprite sheet image -- the very image SpriteRenderer would
-- have drawn. That is what makes RED++ OBJ palette recolors and mod sprite
-- replacements apply to the 3D model with no rebuild and no second copy of
-- the palette logic.
--
-- A model is geometry alone: it names no sheet, and never points into the
-- player's imported cache (MK301). The sheet comes from the spriteDef the
-- engine already handed us, so the pairing is the engine's, not ours.
--
-- The carved models ship inside this mod, but another mod may shadow one
-- by dropping overrides/voxels/<name>.lua -- the same overrides/ directory
-- and the same priority order the engine uses for art. Our own copy is the
-- fallback when nothing shadows it.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local Assets = require("src.render.Assets")
local Voxel3D = V.require("Voxel3D")

local VoxelModels = {}

-- Where a model may live, in priority order.  A voxel model is this mod's
-- own file type -- the cache never holds one -- so rather than route the
-- lookup through Assets.resolve (which only ever rewrites cache paths, and
-- would mean naming a cache path we have no business naming), we walk the
-- engine's override order ourselves and read the same overrides/ directory
-- it would have read.  Highest-priority mod first; our copy last.
local OVERRIDE_DIR = "/overrides/voxels/"
local OWN_DIR = V.path .. "/assets/voxels/"

-- Assets.loader is nil on a mod-free boot and in the headless harness, in
-- which case nothing can be shadowing anything and our own copy is it.
local function candidates(name)
  local paths = {}
  local loader = Assets.loader
  if loader then
    for _, other in ipairs(loader:overrideOrder()) do
      paths[#paths + 1] = other.path .. OVERRIDE_DIR .. name .. ".lua"
    end
  end
  paths[#paths + 1] = OWN_DIR .. name .. ".lua"
  return paths
end

local specs = {}     -- sprite name -> face-list table, or false
local meshes = {}    -- "name#pose" -> mesh, or false

-- the sprite's own image path -> model name, its basename ("red").  The
-- path is whatever the engine put in the spriteDef; we only read its stem.
local function modelName(spriteDef)
  local image = spriteDef and spriteDef.image
  if type(image) ~= "string" then return nil end
  return image:match("([^/\\]+)%.png$")
end

-- The carved face list for a sprite, or nil. Missing models are cached as
-- false: a sprite with no model falls back to a flat billboard, and must
-- not re-hit the filesystem every frame to discover that.
function VoxelModels.spec(spriteDef)
  local name = modelName(spriteDef)
  if not name then return nil end
  if specs[name] == nil then
    local spec = false
    -- first candidate that yields a usable model wins.  A candidate that
    -- is missing OR fails to load keeps the walk going, so a broken
    -- override costs that mod its model, never ours.
    for _, path in ipairs(candidates(name)) do
      if Assets.exists(path) then
        -- love.filesystem, not loadfile: the path may live inside a mounted
        -- .love archive or a mod directory, which plain io cannot reach
        local ok, chunk = pcall(love.filesystem.load, path)
        if ok and chunk then
          local good, value = pcall(chunk)
          if good and type(value) == "table" and value.poses then
            spec = value
            break
          end
        end
      end
    end
    specs[name] = spec
  end
  return specs[name] or nil
end

-- Expand a pose's flat face runs into a mesh. Each face is one quad whose
-- four corners share a single texel centre, so every face is flat-shaded
-- from exactly one sheet pixel -- which is what voxel art wants, and side
-- steps filtering bleed at every face edge for free.
local function buildMesh(spec, pose)
  local p = spec.poses[pose]
  if not p or not p.faces then return nil end
  local faces, n = p.faces, p.count or (#p.faces / 6)
  local sw, sh = spec.sheetW or 16, spec.sheetH or 16
  local verts, indices = {}, {}
  for i = 0, n - 1 do
    local b = i * 6
    local x, y, z = faces[b + 1], faces[b + 2], faces[b + 3]
    local dir, u, v = faces[b + 4], faces[b + 5], faces[b + 6]
    local corners = Voxel3D.FACE_CORNERS[dir]
    if corners then
      local tu, tv = (u + 0.5) / sw, (v + 0.5) / sh
      local shade = Voxel3D.FACE_SHADE[dir] or 1
      for c = 1, 4 do
        local o = corners[c]
        verts[#verts + 1] = { x + o[1], y + o[2], z + o[3], tu, tv, shade }
      end
      Voxel3D.pushQuad(indices, #verts / 4 - 1)
    end
  end
  return Voxel3D.newMesh(verts, indices)
end

-- The mesh for one (sprite, pose). `pose` is "stand" or "walk"; a sheet
-- with no walk frames falls back to its stand model, which is what a
-- 3-frame NPC does in 2D too (it turns to face but never animates).
function VoxelModels.mesh(spriteDef, pose)
  local spec = VoxelModels.spec(spriteDef)
  if not spec then return nil end
  if not spec.poses[pose] then pose = "stand" end
  local key = (spec.name or "?") .. "#" .. pose
  if meshes[key] == nil then
    local ok, mesh = pcall(buildMesh, spec, pose)
    meshes[key] = (ok and mesh) or false
  end
  return meshes[key] or nil
end

function VoxelModels.size(spriteDef)
  local spec = VoxelModels.spec(spriteDef)
  return spec and spec.size or 16
end

function VoxelModels.invalidate()
  specs = {}
  meshes = {}
end

Assets.register(VoxelModels.invalidate)

return VoxelModels
