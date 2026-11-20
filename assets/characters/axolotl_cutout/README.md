# Axolotl original-pixel cutout preview

- `source.png`: supplied drawing, copied unchanged; no generated artwork is used.
- `parts/`: 13 disjoint transparent PNG selections: head, six gills, torso, tail, front arm, staff with holding arm, two boots.
- `rig_parts/`: the same original selections with a four-pixel source-image overlap at seams for animation.
- `rig.json`: original-canvas pivots, parent joints, crop bounds and draw order.
- `preview/idle.gif`: 64 frames, 50 ms/frame, 3.2-second infinite idle loop.
- Gill rotation is ±12 degrees (previously ±1.8), with a 0.35-radian delay between upper/middle/lower gills. `preview/idle_subtle.gif` preserves the previous motion for comparison.
- `preview/parts_sheet.png`, `motion_check.png`: visual inspection sheets.
- `preview/assembled.png`: neutral reconstruction, byte-for-byte RGBA equality checked against the source.
- `preview/validation.json`: scoped artifact validation result.

Run `tools/build_axolotl_cutout.py <source.png>` with Python, Pillow and NumPy to reproduce. Preview scene: `res://scenes/dev/axolotl_cutout_preview.tscn`. Stages 62 and 63 install this rig as their player visual. Stage 63 matches the original opaque height; stage 62 uses 1.17x that size (10% smaller than its previous 1.3x) with a white antialiased outline. Both preserve the original boot midpoint and baseline. All other stages keep the original player. This is a rigid joint cutout rig, not a deforming mesh or a Skeleton2D skin. The staff and its hand/arm remain one rigid part to preserve the grip.

The original has no hidden shoulder, neck or tail-root artwork. Small rotations and source-pixel overlaps reduce exposed cuts; large gestures need manually completed hidden artwork. Source contour fragments and overlap edges can still show at joints. GIF frames were inspected; this does not validate gameplay. Godot's scoped headless script check crashed with signal 11, so the live Godot preview is unverified.
