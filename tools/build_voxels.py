#!/usr/bin/env python3
"""Build voxel models for the overworld sprites (voxel world mode, Tier 3).

An AUTHORING tool, run by hand against a machine that has imported its own
ROM.  It reads the extracted overworld sprite sheets out of the local cache
and emits, per sheet, the mod's own assets/voxels/<name>.lua -- a face list
the runtime (lib/VoxelModels.lua) turns into a LOVE Mesh.

The emitted model is geometry only: it names no sheet and bakes no pixel,
so what ships is the mod's own carving, not cache content (MK301).  The
runtime pairs a model with the LIVE sheet the engine already handed it.

Core idea
---------
A GB overworld sheet gives THREE orthographic silhouettes of one character:
facing down (front), facing up (back), facing left (side; right is the
mirror). Three orthogonal views is exactly what visual-hull / space carving
needs:

    solid(x, y, z) = (front[y, x] OR back'[y, x]) AND side[y, z]

where back' is the back view mirrored horizontally so it registers with the
front (walk behind someone and left/right swap).

Note the OR. The front and back constrain the SAME axis -- they are two
observations of one [x, y] outline -- so ANDing them erodes the model
wherever the two frames disagree, and GB walk art disagrees often (Seel's
back frame splays its flippers where the front frame has body). Measured
over all 67 sheets, the union is never worse on reprojection IoU and better
on 16, and it fails toward "slightly fat" rather than "chunks missing",
which is the right failure mode for voxel art: 51 sheets whose two frames
agree exactly are bit-identical either way. Only the orthogonal side view
actually carves depth, and it still ANDs. `--silhouette intersect` restores
the strict three-way hull.

Carving grid (sprite-pixel aligned):
    x = front-sprite column      y = sprite row, 0 = top
    z = side-sprite column, 0 = the character's front (nose / hat brim)

Faces are exported in MODEL space, which is the runtime's world convention
(X = map east, Y = up, Z = map south) with the character facing +Z (south,
"down") at rest, so the runtime only has to yaw by facing:

    mx = x        my = 15 - y        mz = 15 - z

Texturing
---------
A face does NOT carry a baked color. It carries the sheet pixel (u, v) of
the view it faces, so the runtime samples the LIVE sprite sheet image. That
is what makes RED++ OBJ-palette recolors (SpriteRenderer's OBP bake) and
mod sprite replacements color the voxel model for free, with no rebuild.

Pipeline
--------
 1. decode    PNG (RGBA, GB 4-shade) or raw 2bpp -> shade indices 0..3
 2. alpha     the PNG alpha channel when the source has one (extracted
              sheets key GB OBJ color 0 to alpha 0, matching the hardware
              rule that OBJ palette index 0 is always transparent); raw
              2bpp has no alpha, so it falls back to flood-filling shade 0
              in from the frame border
 3. anchor    bottom-center align each view's opaque bbox (feet on ground)
              so views authored with different padding still register
 4. carve     intersect the three extruded silhouettes
 5. clean     keep the largest 6-connected component (kills carve speckle)
 6. faces     emit every exposed voxel face with the sheet pixel it samples
 7. export    <name>.lua (+ optional .vox / .ply for authoring in
              MagicaVoxel / Blender)
 8. validate  re-project the hull along each axis, report IoU against the
              source silhouettes -- the hull can only shrink, so IoU < 1
              flags real loss (misregistered views, over-carving)

Poses
-----
6-frame sheets (16x96) carry stand down/up/left in frames 0,1,2 and walk
down/up/left in 3,4,5 -> a "stand" and a "walk" model.
3-frame sheets (16x48) are stand-only.
1-frame sheets (16x16, props: boulder / fossil / clipboard) have no other
view at all, so the side silhouette is the mirrored front -- which carves
the symmetric solid a prop reads as.

Usage
-----
  python3 tools/build_voxels.py                     # whole sprite dir
  python3 tools/build_voxels.py --only red,oak
  python3 tools/build_voxels.py --debug-exports -o /tmp/vox
"""

from __future__ import annotations

import argparse
import struct
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

FRAME = 16              # overworld sprites are 16x16
SHADES = 4              # GB is 2bpp

# the author's own imported cache is the INPUT to this build step; only the
# carved output below is what the mod ships
SPRITE_DIR = Path("assets/generated/sprites")
# ...and it lands in the mod's own asset tree, never back in the cache
VOXEL_DIR = Path("mods/DRAMATIC_SHAPE/assets/voxels")

# shade index (0 = lightest) -> RGBA, for the .vox / .ply debug exports only
# (the runtime textures from the live sheet instead -- see module docstring)
PALETTES = {
    "gray": [(248, 248, 248, 255), (168, 168, 168, 255),
             (88, 88, 88, 255), (16, 16, 16, 255)],
    "gb":   [(224, 248, 208, 255), (136, 192, 112, 255),
             (52, 104, 86, 255), (8, 24, 32, 255)],
    "sgb":  [(255, 239, 206, 255), (222, 148, 74, 255),
             (173, 41, 33, 255), (49, 24, 82, 255)],
}


# ---------------------------------------------------------------- decoding --

def decode_2bpp(data: bytes, tiles_wide: int = 2) -> np.ndarray:
    """Raw GB 2bpp -> 2D array of shade indices. 16 bytes per 8x8 tile, two
    bytes per row: byte0 = low bitplane, byte1 = high bitplane."""
    ntiles = len(data) // 16
    tiles = []
    for t in range(ntiles):
        chunk = data[t * 16:(t + 1) * 16]
        tile = np.zeros((8, 8), np.uint8)
        for row in range(8):
            lo, hi = chunk[row * 2], chunk[row * 2 + 1]
            for bit in range(8):
                tile[row, bit] = (((hi >> (7 - bit)) & 1) << 1) | \
                                 ((lo >> (7 - bit)) & 1)
        tiles.append(tile)
    rows = [np.hstack(tiles[i:i + tiles_wide])
            for i in range(0, ntiles, tiles_wide)]
    return np.vstack(rows)


def load_sheet(path: Path):
    """Load a sheet as (shade indices 0..3, alpha mask or None).

    The extracted PNGs are RGBA with GB OBJ color 0 written as transparent
    white, so their alpha channel IS the opacity mask -- exact, and what the
    hardware does. `None` means the source carried no alpha (raw 2bpp, or a
    flat grayscale PNG) and the caller must derive opacity itself."""
    if path.suffix.lower() == ".2bpp":
        return decode_2bpp(path.read_bytes()), None
    arr = np.array(Image.open(path).convert("RGBA"))
    lum = arr[..., 0].astype(np.int16)     # GB art is gray: R == G == B
    shade = np.zeros(lum.shape, np.uint8)  # bucket; don't trust exact values
    shade[lum < 213] = 1
    shade[lum < 128] = 2
    shade[lum < 43] = 3
    alpha = arr[..., 3] > 0 if arr[..., 3].min() < 255 else None
    return shade, alpha


def slice_frames(shade: np.ndarray, alpha):
    """Split a sheet into 16x16 frames, row-major over any grid layout.
    Returns (shade, alpha_or_None, origin_x, origin_y) per frame; the origin
    is the frame's top-left in sheet pixels, which is what the exported UVs
    are relative to."""
    h, w = shade.shape
    out = []
    for fy in range(h // FRAME):
        for fx in range(w // FRAME):
            sy, sx = fy * FRAME, fx * FRAME
            sub = shade[sy:sy + FRAME, sx:sx + FRAME]
            sub_a = alpha[sy:sy + FRAME, sx:sx + FRAME] if alpha is not None \
                else None
            out.append((sub, sub_a, sx, sy))
    return out


# ------------------------------------------------------------------- alpha --

def flood_alpha(shade: np.ndarray) -> np.ndarray:
    """Fallback opacity for alpha-less sources: shade 0 is transparent ONLY
    where it flood-connects to the frame border, so an enclosed light region
    (a face, a hand) stays opaque instead of punching a hole through the
    model."""
    h, w = shade.shape
    bg = np.zeros((h, w), bool)
    dq = deque()

    def seed(y, x):
        if shade[y, x] == 0 and not bg[y, x]:
            bg[y, x] = True
            dq.append((y, x))

    for x in range(w):
        seed(0, x)
        seed(h - 1, x)
    for y in range(h):
        seed(y, 0)
        seed(y, w - 1)
    while dq:
        y, x = dq.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w:
                seed(ny, nx)
    return ~bg


def anchor_bottom_center(shade: np.ndarray, alpha: np.ndarray):
    """Shift a frame so its opaque bbox sits bottom-anchored and horizontally
    centered, returning (shade, alpha, dy, dx). Views are authored with
    slightly different padding; without this the hull loses a pixel shell
    wherever they disagree. The shifts come back out because the exported UVs
    must point at the ORIGINAL sheet pixel, not the shifted one."""
    ys, xs = np.nonzero(alpha)
    if len(ys) == 0:
        return shade, alpha, 0, 0
    dy = (FRAME - 1) - int(ys.max())
    dx = (FRAME - (int(xs.max()) - int(xs.min()) + 1)) // 2 - int(xs.min())
    out_s = np.zeros_like(shade)
    out_a = np.zeros_like(alpha)
    out_s[ys + dy, xs + dx] = shade[ys, xs]
    out_a[ys + dy, xs + dx] = True
    return out_s, out_a, dy, dx


class View:
    """One aligned silhouette plus the mapping back to its sheet pixels.

    `mirror` is applied BEFORE alignment: the back view is pre-mirrored so it
    registers with the front (and a prop's synthetic side view is the
    mirrored front), which keeps the carve and the UV lookup working in one
    consistent aligned space with no second flip anywhere downstream."""

    def __init__(self, shade, alpha, ox, oy, mirror=False):
        if mirror:
            shade = shade[:, ::-1].copy()
            alpha = alpha[:, ::-1].copy()
        self.shade, self.alpha, self.dy, self.dx = \
            anchor_bottom_center(shade, alpha)
        self.ox, self.oy, self.mirror = ox, oy, mirror

    def opaque(self, row: int, col: int) -> bool:
        return bool(self.alpha[row, col])

    def uv(self, row: int, col: int):
        """Aligned (row, col) -> (u, v) sheet pixel. Callers only ask for
        positions this view proved opaque (see `sample`), so the inverse
        lands inside the frame; the clamp guards a degenerate frame."""
        y0 = row - self.dy
        x0 = col - self.dx
        if self.mirror:
            x0 = FRAME - 1 - x0
        y0 = min(max(y0, 0), FRAME - 1)
        x0 = min(max(x0, 0), FRAME - 1)
        return self.ox + x0, self.oy + y0


# ------------------------------------------------------------------- carve --

def carve(front: View, side: View, back: View, mode="union") -> np.ndarray:
    """Visual hull: solid[x, y, z]. `back` is already registered with the
    front (pre-mirrored at construction), so no flip here. The front/back
    pair combines by `mode` (see the module docstring); the orthogonal side
    view always intersects, since it is the only view carving depth."""
    fb = front.alpha | back.alpha if mode == "union" else \
        front.alpha & back.alpha
    return fb.T[:, :, None] & side.alpha[None, :, :]   # [x,y,1] & [1,y,z]


def largest_component(solid: np.ndarray) -> np.ndarray:
    """Keep only the largest 6-connected blob (drops carving speckle)."""
    labels = np.zeros(solid.shape, np.int32)
    best_id, best_n, cur = 0, 0, 0
    for idx in zip(*np.nonzero(solid)):
        if labels[idx]:
            continue
        cur += 1
        n = 0
        dq = deque([idx])
        labels[idx] = cur
        while dq:
            x, y, z = dq.popleft()
            n += 1
            for dx, dy, dz in ((1, 0, 0), (-1, 0, 0), (0, 1, 0),
                               (0, -1, 0), (0, 0, 1), (0, 0, -1)):
                nx, ny, nz = x + dx, y + dy, z + dz
                if 0 <= nx < FRAME and 0 <= ny < FRAME and 0 <= nz < FRAME \
                        and solid[nx, ny, nz] and not labels[nx, ny, nz]:
                    labels[nx, ny, nz] = cur
                    dq.append((nx, ny, nz))
        if n > best_n:
            best_id, best_n = cur, n
    return labels == best_id


# ------------------------------------------------------------------- faces --

# carve-grid neighbour offset -> (model direction id, which view colors it).
# Model dirs: 1 = +X east, 2 = -X west, 3 = +Y up, 4 = -Y down,
#             5 = +Z south (toward the camera), 6 = -Z north (away).
# A profile face takes the side view -- and so do TOP faces: the camera in
# game looks steeply down, so tops dominate what you see, and the axis a
# top face varies along on screen is DEPTH (z). The side view is the one
# view that resolves depth -- its pixel at (row, z) puts cap-front red and
# hair-back black in the right z order. Sampling the front view there (the
# obvious first guess, and what shipped first) gives every top voxel of a
# row the same front pixel, which painted the entire head cap-color and
# turned every character into a red-topped blob.
FACE_DIRS = (
    ((1, 0, 0), 1, "side"),
    ((-1, 0, 0), 2, "side"),
    ((0, -1, 0), 3, "side"),
    ((0, 1, 0), 4, "front"),
    ((0, 0, -1), 5, "front"),
    ((0, 0, 1), 6, "back"),
)


def source_view(which, x, y, z, front: View, side: View, back: View):
    """The view a face takes its pixel from, as (view, row, col) in that
    view's ALIGNED space, with a fallback chain.

    Under the union rule a voxel can be proved solid by the back view alone,
    so its front-facing face has no front pixel to take -- sampling one
    anyway would read the frame's transparent background and punch a hole in
    the model. Fall back to the opposite same-axis view, then to the side
    view, which every solid voxel satisfies by construction (the side is the
    one view that always intersects), so this always terminates on an opaque
    pixel."""
    if which == "side":
        return side, y, z
    first, second = (front, back) if which == "front" else (back, front)
    if first.opaque(y, x):
        return first, y, x
    if second.opaque(y, x):
        return second, y, x
    return side, y, z


def build_faces(solid, front: View, side: View, back: View):
    """Every exposed voxel face as (mx, my, mz, dir, u, v) in model space.

    The model's own underside (my == 0) is dropped: it sits flat on the
    ground plane and can never be seen, and it is ~1 face in 8."""
    faces = []
    for x, y, z in zip(*np.nonzero(solid)):
        x, y, z = int(x), int(y), int(z)
        mx, my, mz = x, FRAME - 1 - y, FRAME - 1 - z
        for (dx, dy, dz), d, which in FACE_DIRS:
            nx, ny, nz = x + dx, y + dy, z + dz
            if 0 <= nx < FRAME and 0 <= ny < FRAME and 0 <= nz < FRAME \
                    and solid[nx, ny, nz]:
                continue
            if d == 4 and my == 0:
                continue
            v, r, c = source_view(which, x, y, z, front, side, back)
            u, w = v.uv(r, c)
            faces.append((mx, my, mz, d, u, w))
    return faces


def colorize(solid, front: View, side: View, back: View) -> np.ndarray:
    """Per-voxel shade index for the .vox / .ply debug exports. Priority
    front > side > back > top, matching the face order the runtime sees;
    bottom-only voxels keep the darkest shade (they read as shadow). Shades
    resolve through `source_view`'s fallback chain for the same reason the
    exported UVs do -- a back-only voxel has no front pixel."""
    shade = np.full(solid.shape, 3, np.uint8)

    def free(x, y, z, dx, dy, dz):
        nx, ny, nz = x + dx, y + dy, z + dz
        return not (0 <= nx < FRAME and 0 <= ny < FRAME and 0 <= nz < FRAME
                    and solid[nx, ny, nz])

    def shade_at(which, x, y, z):
        v, r, c = source_view(which, x, y, z, front, side, back)
        return v.shade[r, c]

    for x, y, z in zip(*np.nonzero(solid)):
        x, y, z = int(x), int(y), int(z)
        if free(x, y, z, 0, 0, -1):
            shade[x, y, z] = shade_at("front", x, y, z)
        elif free(x, y, z, 1, 0, 0) or free(x, y, z, -1, 0, 0):
            shade[x, y, z] = shade_at("side", x, y, z)
        elif free(x, y, z, 0, 0, 1):
            shade[x, y, z] = shade_at("back", x, y, z)
        elif free(x, y, z, 0, -1, 0):
            shade[x, y, z] = shade_at("side", x, y, z)
    return shade


# -------------------------------------------------------------- validation --

def reprojection_iou(solid, front: View, side: View, back: View) -> dict:
    """Project the hull back along each axis against the source silhouettes.
    Front and back project along the same axis (the back is pre-registered),
    so they share a projection and differ only in what they are compared to."""
    proj_fb = solid.any(axis=2).T          # [y, x]
    proj_side = solid.any(axis=0)          # [y, z]

    def iou(a, b):
        u = (a | b).sum()
        return float((a & b).sum()) / u if u else 1.0

    return {"front": iou(proj_fb, front.alpha),
            "side": iou(proj_side, side.alpha),
            "back": iou(proj_fb, back.alpha)}


# ----------------------------------------------------------- debug exports --

def _chunk(cid: bytes, content: bytes, children: bytes = b"") -> bytes:
    return cid + struct.pack("<ii", len(content), len(children)) \
        + content + children


def write_vox(path: Path, solid, shade, palette):
    """MagicaVoxel .vox (z-up). Model axes: vox_x = x, vox_y = depth,
    vox_z = up."""
    xs, ys, zs = np.nonzero(solid)
    xyzi = struct.pack("<i", len(xs))
    for x, y, z in zip(xs, ys, zs):
        xyzi += struct.pack("<4B", int(x), int(FRAME - 1 - z),
                            int(FRAME - 1 - y), int(shade[x, y, z]) + 1)
    pal = bytearray()
    for i in range(255):
        pal += bytes(palette[i]) if i < len(palette) else b"\x00\x00\x00\xff"
    pal += b"\x00\x00\x00\x00"
    children = _chunk(b"SIZE", struct.pack("<3i", FRAME, FRAME, FRAME)) \
        + _chunk(b"XYZI", xyzi) + _chunk(b"RGBA", bytes(pal))
    path.write_bytes(b"VOX " + struct.pack("<i", 150)
                     + _chunk(b"MAIN", b"", children))


_PLY_FACES = {  # (dx,dy,dz) -> 4 corner offsets (unit cube, CCW from outside)
    (0, 0, -1): [(0, 0, 0), (1, 0, 0), (1, 1, 0), (0, 1, 0)],
    (0, 0, 1):  [(1, 0, 1), (0, 0, 1), (0, 1, 1), (1, 1, 1)],
    (-1, 0, 0): [(0, 0, 1), (0, 0, 0), (0, 1, 0), (0, 1, 1)],
    (1, 0, 0):  [(1, 0, 0), (1, 0, 1), (1, 1, 1), (1, 1, 0)],
    (0, -1, 0): [(0, 0, 1), (1, 0, 1), (1, 0, 0), (0, 0, 0)],
    (0, 1, 0):  [(0, 1, 0), (1, 1, 0), (1, 1, 1), (0, 1, 1)],
}


def write_ply(path: Path, solid, shade, palette):
    """ASCII PLY, hidden faces culled, vertex colors. y flipped so +up."""
    verts, faces = [], []
    for x, y, z in zip(*np.nonzero(solid)):
        r, g, b, _ = palette[shade[x, y, z]]
        for (dx, dy, dz), corners in _PLY_FACES.items():
            nx, ny, nz = x + dx, y + dy, z + dz
            if 0 <= nx < FRAME and 0 <= ny < FRAME and 0 <= nz < FRAME \
                    and solid[nx, ny, nz]:
                continue
            base = len(verts)
            for cx, cy, cz in corners:
                verts.append((x + cx, FRAME - (y + cy), z + cz, r, g, b))
            faces.append((base, base + 1, base + 2, base + 3))
    with open(path, "w") as f:
        f.write("ply\nformat ascii 1.0\n"
                f"element vertex {len(verts)}\n"
                "property float x\nproperty float y\nproperty float z\n"
                "property uchar red\nproperty uchar green\n"
                "property uchar blue\n"
                f"element face {len(faces)}\n"
                "property list uchar int vertex_indices\nend_header\n")
        for v in verts:
            f.write("%g %g %g %d %d %d\n" % v)
        for a, b, c, d in faces:
            f.write(f"4 {a} {b} {c} {d}\n")


# ------------------------------------------------------------- lua exports --

FACES_PER_LINE = 8


def lua_source(name: str, sheet_w: int, sheet_h: int, poses: dict) -> str:
    out = [
        "-- Generated by tools/build_voxels.py. DO NOT EDIT.",
        f"-- Visual-hull voxel model carved from the {name!r} overworld"
        .replace("'", '"'),
        "-- sprite sheet.  Geometry only -- no sheet path, no baked pixel.",
        "-- faces: flat runs of 6 ints -- mx, my, mz, dir, u, v.",
        "--   mx/my/mz  voxel corner in model space (X east, Y up, Z south),",
        "--             0..15, character faces +Z at rest.",
        "--   dir       1 +X  2 -X  3 +Y  4 -Y  5 +Z  6 -Z",
        "--   u/v       pixel this face samples in a sheet of sheetW x sheetH.",
        "--             The runtime pairs the model with the LIVE sheet the",
        "--             engine handed it, so palette/mod recolors apply.",
        "return {",
        f"  name = {name!r},".replace("'", '"'),
        f"  sheetW = {sheet_w},",
        f"  sheetH = {sheet_h},",
        f"  size = {FRAME},",
        "  poses = {",
    ]
    for pose in ("stand", "walk"):
        p = poses.get(pose)
        if not p:
            continue
        faces = p["faces"]
        out.append(f"    {pose} = {{")
        out.append(f"      frames = {{ {', '.join(str(f) for f in p['frames'])} }},")
        out.append(f"      voxels = {p['voxels']},")
        out.append(f"      count = {len(faces)},")
        out.append("      faces = {")
        for i in range(0, len(faces), FACES_PER_LINE):
            chunk = faces[i:i + FACES_PER_LINE]
            row = " ".join(
                ",".join(str(n) for n in face) + "," for face in chunk)
            out.append("        " + row)
        out.append("      },")
        out.append("    },")
    out.append("  },")
    out.append("}")
    return "\n".join(out) + "\n"


# ---------------------------------------------------------------- pipeline --

def build_pose(frames, picks, mode="union"):
    """Carve one pose. `picks` is (down, up, left) frame indices, or a
    1-tuple for a prop, whose side view is the mirrored front."""
    def view(i, mirror=False):
        shade, alpha, ox, oy = frames[i]
        if alpha is None:
            alpha = flood_alpha(shade)
        return View(shade, alpha, ox, oy, mirror)

    if len(picks) == 1:
        front = view(picks[0])
        back = view(picks[0], mirror=True)   # a prop reads the same from behind
        side = view(picks[0], mirror=True)
    else:
        front = view(picks[0])
        back = view(picks[1], mirror=True)   # register the back with the front
        side = view(picks[2])

    solid = largest_component(carve(front, side, back, mode))
    return solid, front, side, back


def convert(path: Path, outdir: Path, debug: Path = None,
            palette_name="sgb", min_iou=0.0, mode="union") -> dict:
    shade, alpha = load_sheet(path)
    frames = slice_frames(shade, alpha)
    sheet_h, sheet_w = shade.shape

    if len(frames) >= 6:
        pose_picks = {"stand": (0, 1, 2), "walk": (3, 4, 5)}
    elif len(frames) >= 3:
        pose_picks = {"stand": (0, 1, 2)}
    else:
        pose_picks = {"stand": (0,)}

    poses, scores = {}, {}
    for pose, picks in pose_picks.items():
        solid, front, side, back = build_pose(frames, picks, mode)
        poses[pose] = {
            "frames": picks,
            "voxels": int(solid.sum()),
            "faces": build_faces(solid, front, side, back),
        }
        scores[pose] = reprojection_iou(solid, front, side, back)
        if debug is not None:
            palette = PALETTES[palette_name]
            sh = colorize(solid, front, side, back)
            debug.mkdir(parents=True, exist_ok=True)
            write_vox(debug / f"{path.stem}_{pose}.vox", solid, sh, palette)
            write_ply(debug / f"{path.stem}_{pose}.ply", solid, sh, palette)

    outdir.mkdir(parents=True, exist_ok=True)
    dest = outdir / f"{path.stem}.lua"
    dest.write_text(lua_source(path.stem, sheet_w, sheet_h, poses))

    # report the WORST pose, not just stand: `ok` gates on every pose, so a
    # summary line showing stand's numbers could print "!!" beside three
    # healthy-looking scores when it is the walk pose that carved badly
    worst_pose = min(scores, key=lambda p: min(scores[p].values()))
    worst = min(scores[worst_pose].values())
    return {"name": path.stem, "poses": poses, "iou": scores,
            "worst": worst, "worstPose": worst_pose, "ok": worst >= min_iou,
            "bytes": dest.stat().st_size}


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("input", nargs="?", type=Path, default=SPRITE_DIR,
                    help="sprite PNG/.2bpp or directory "
                         f"(default {SPRITE_DIR})")
    ap.add_argument("-o", "--outdir", type=Path, default=VOXEL_DIR)
    ap.add_argument("--only", help="comma-separated sprite stems to build")
    ap.add_argument("--debug-exports", type=Path, default=None,
                    metavar="DIR", help="also write .vox/.ply there")
    ap.add_argument("--palette", choices=PALETTES, default="sgb",
                    help="debug-export palette only")
    ap.add_argument("--min-iou", type=float, default=0.0,
                    help="fail the run if any view scores below this")
    ap.add_argument("--silhouette", choices=("union", "intersect"),
                    default="union",
                    help="how the front/back pair combines (see the module "
                         "docstring); intersect is the strict three-way hull")
    args = ap.parse_args(argv)

    if args.input.is_dir():
        targets = sorted(args.input.glob("*.png")) + \
            sorted(args.input.glob("*.2bpp"))
    else:
        targets = [args.input]
    if args.only:
        keep = {s.strip() for s in args.only.split(",") if s.strip()}
        targets = [t for t in targets if t.stem in keep]
    if not targets:
        print(f"no sprite sheets found under {args.input}")
        return 1

    failed, total_faces, total_bytes = 0, 0, 0
    for t in targets:
        try:
            r = convert(t, args.outdir, args.debug_exports, args.palette,
                        args.min_iou, args.silhouette)
        except Exception as e:                # noqa: BLE001 - batch robustness
            print(f"[FAIL] {t.name}: {e}")
            failed += 1
            continue
        nf = sum(len(p["faces"]) for p in r["poses"].values())
        total_faces += nf
        total_bytes += r["bytes"]
        s = r["iou"][r["worstPose"]]
        flag = "" if r["ok"] else "  <-- below min IoU"
        pose = "" if r["worstPose"] == "stand" else f" [{r['worstPose']}]"
        print(f"[{'ok' if r['ok'] else '!!'}] {r['name']:<20}"
              f" {len(r['poses'])} pose(s)  {nf:>5} faces  "
              f"IoU f={s['front']:.3f} s={s['side']:.3f} b={s['back']:.3f}"
              f"{pose}{flag}")
        failed += not r["ok"]

    print(f"\n{len(targets) - failed}/{len(targets)} models -> {args.outdir}"
          f"  ({total_faces} faces, {total_bytes / 1024:.0f} KiB)")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
