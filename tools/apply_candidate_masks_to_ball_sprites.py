from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets/balls/generated"
CANDIDATES = ASSETS / "mask_candidates"
SIZE = 418
CENTER = SIZE / 2

assignments = {
    2: ("01_rounded_triangle.png", (-18.000004, -18.499996), (1.0861243, 1.083732)),
    4: ("02_four_petal.png", (-26.0, 13.0), (1.0, 1.0)),
    5: ("03_soft_bean.png", (-8.0, 30.0), (1.0, 1.0)),
    6: ("04_squircle.png", (0.0, 18.0), (1.0, 1.0)),
    7: ("05_egg.png", (-35.5, 52.5), (0.9832536, 0.9832536)),
    8: ("06_pebble.png", (-14.0, 43.0), (1.0, 1.0)),
    9: ("07_puffy_star.png", (7.0, 50.999996), (0.9665072, 0.9665072)),
    10: ("08_flat_bubble.png", (-9.499919, -2.499919), (0.44983068, 0.44983068)),
}

for number, (candidate_name, position, scale) in assignments.items():
    root_mask = Image.open(CANDIDATES / candidate_name).convert("RGBA")
    sx, sy = scale
    px, py = position
    sprite_size = Image.open(ASSETS / f"ball_{number:02d}_axolotl_source.png").size
    sprite_cx, sprite_cy = sprite_size[0] / 2, sprite_size[1] / 2
    affine = (sx, 0, CENTER + px - sx * sprite_cx, 0, sy, CENTER + py - sy * sprite_cy)
    transformed = root_mask.transform(sprite_size, Image.Transform.AFFINE, affine, Image.Resampling.BICUBIC)
    transformed.save(ASSETS / f"ball_{number:02d}_axolotl_shape_mask.png")
