"""Build stage 63's single convex polygons from heart/star shell masks.

Uses only the Python standard library; does not touch shared ball assets.
"""
from pathlib import Path
import math
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
MASKS = {
    3: "assets/balls/generated/orb_outline_heart_mask.png",
    6: "assets/balls/generated/mask_candidates/07_puffy_star.png",
}


def read_alpha(path):
    data = path.read_bytes()
    pos, compressed = 8, b""
    while pos < len(data):
        size = struct.unpack_from(">I", data, pos)[0]
        kind, chunk = data[pos + 4:pos + 8], data[pos + 8:pos + 8 + size]
        if kind == b"IHDR":
            width, height, depth, color, _, _, interlace = struct.unpack(">IIBBBBB", chunk)
            assert depth == 8 and color in (4, 6) and interlace == 0, path
        if kind == b"IDAT":
            compressed += chunk
        pos += size + 12
    bpp = 4 if color == 6 else 2
    raw, stride = zlib.decompress(compressed), width * bpp
    previous, alpha, offset = bytearray(stride), [], 0
    for _ in range(height):
        mode = raw[offset]
        row = bytearray(raw[offset + 1:offset + 1 + stride])
        offset += stride + 1
        for x in range(stride):
            a, b, c = (row[x - bpp] if x >= bpp else 0), previous[x], (previous[x - bpp] if x >= bpp else 0)
            if mode == 1:
                row[x] = (row[x] + a) & 255
            elif mode == 2:
                row[x] = (row[x] + b) & 255
            elif mode == 3:
                row[x] = (row[x] + (a + b) // 2) & 255
            elif mode == 4:
                p = a + b - c
                distances = abs(p - a), abs(p - b), abs(p - c)
                predictor = (a, b, c)[distances.index(min(distances))]
                row[x] = (row[x] + predictor) & 255
            else:
                assert mode == 0
        alpha.append(row[bpp - 1::bpp])
        previous = row
    return width, height, alpha


def cross(a, b, c):
    return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])


def fit(path, limit=24):
    width, height, alpha = read_alpha(path)
    # Row extrema suffice for the exact convex hull of the thresholded mask.
    points = []
    for y, row in enumerate(alpha):
        xs = [x for x, value in enumerate(row) if value >= 128]
        if xs:
            points.extend(((xs[0] + .5, y + .5), (xs[-1] + .5, y + .5)))
    points = sorted(set(points))
    lower, upper = [], []
    for point in points:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], point) <= 0:
            lower.pop()
        lower.append(point)
    for point in reversed(points):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], point) <= 0:
            upper.pop()
        upper.append(point)
    hull = lower[:-1] + upper[:-1]
    full_hull = list(hull)
    # Keep the visually important corners while removing near-collinear pixels.
    while len(hull) > limit:
        index = min(range(len(hull)), key=lambda i: abs(cross(hull[i-1], hull[i], hull[(i+1)%len(hull)])))
        hull.pop(index)
    assert all(cross(hull[i-1], hull[i], hull[(i+1)%len(hull)]) > 0 for i in range(len(hull)))
    max_error = 0.0
    for point in full_hull:
        closest = float('inf')
        for i, a in enumerate(hull):
            b = hull[(i+1)%len(hull)]
            dx, dy = b[0]-a[0], b[1]-a[1]
            t = max(0., min(1., ((point[0]-a[0])*dx+(point[1]-a[1])*dy)/(dx*dx+dy*dy)))
            closest = min(closest, math.hypot(point[0]-a[0]-t*dx, point[1]-a[1]-t*dy))
        max_error = max(max_error, closest)
    return [(x-width/2, y-height/2) for x,y in hull], max_error


if __name__ == "__main__":
    output = ROOT / "resources/compound_pond_polygon_profiles.tres"
    lines = ['[gd_resource type="Resource" load_steps=2 format=3]', '',
             '[ext_resource type="Script" path="res://scripts/gimmicks/configs/compound_pond_polygon_profiles.gd" id="1"]', '',
             '[resource]', 'script = ExtResource("1")']
    for stage, mask in MASKS.items():
        points, error = fit(ROOT / mask)
        values = ", ".join(f"{v:.5f}" for point in points for v in point)
        lines.append(f"stage_{stage:02d} = PackedVector2Array({values})")
        print(f"stage {stage}: one strictly convex {len(points)}-vertex polygon; max original-hull boundary error {error:.3f} source px")
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
