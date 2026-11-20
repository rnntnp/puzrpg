# 63. 모양대로 연못

Status: `NEEDS_PLAYTEST`. User-specified collision comparison with stage 62.

## Current contract

- Only heart (displayed 3) and star (6) replace their original hitboxes with **one ConvexPolygonShape2D each**, fitted to the alpha-mask convex hull and simplified to 24 vertices. This deliberately fills the heart notch and star valleys to maintain a single convex shape. Supersedes the previous 11/12-circle experiment after user-reported trembling.
- Other stages retain their original hitbox composition. Every stage scales collider dimensions and local offsets by 1.05 around the body origin; artwork size stays unchanged. Shapes are private per body; shared BallData and stage 62 are untouched.
- Warp directly inherits 62's six controls, strongest-four direction groups, body-level onset/release filters, spring integration, impact sharing and wall-control clamp. Only contact positions use the installed shapes. Polygon face supports follow the physical contact along the face, avoiding arbitrary endpoint selection.
- Contact continuity (2026-11-14): native reports seed a body-level contact history. Before each visual update, GJK distance/witness points are computed from the actual enabled circle/capsule/convex-polygon/rectangle shapes. Previously confirmed neighbors remain touching through missing reports while the minimum gap is at most `contact_release_gap=0.5` board pixels; larger separation, removal, disabled shapes or merge-lock remove the contact and invoke the inherited release filter. Nearby unconfirmed bodies are not discovered by this history. No hold timer, enclosing-radius approximation or physical force is used.
- All geometrically maintained neighbors feed touch identity and anchor continuity, independently of strongest-four spring forcing. This prevents report/direction-budget flicker from resetting the body-level onset/release filter. State histories are discarded with the visual layer.
- Preview, launch guide, new balls and merge results use the installed shapes. One rigid body owns mass, inertia and merge identity. No new forces or physical deformation are added.
- Existing bottom directional launcher, reflected side-wall flight, upward gravity after landing, loadout, three enemies, infinite test HP, lower Danger Line, normal merge/chain/damage/Skill Gauge and board persistence are reused. No new enemy action or failure rule.
- Stage 63 replaces the player's image with the original-pixel 13-part axolotl rig: 3.2-second idle, ±12° gills with upper/middle/lower phase offsets. Uniform scaling matches the old drawing's opaque height; the midpoint of both boots and their lowest edge match the old foot band. Fighter position, shadow, combat data and root hit/movement feedback are retained. Cast-specific sprite swapping stays hidden behind the same idle rig. Cleanup restores the original sprite. Stage 62 also opts into this rig at 1.17x size with a white antialiased outline with the same foot anchor; stage 63 remains at 1.0x. Other stages keep the shared player unchanged.
- Cleanup/restart/handler replacement restore original shapes, radius, contact budget, inertia, observers, materials and launcher state. Normal same-stage merging remains body-based and grants no extra effects for multiple contact points.

## Implementation and tuning

- `scripts/gimmicks/handlers/compound_pond_handler.gd` and the existing isolated collider/launcher/warp helpers. No Battle or MonsterActionController branches.
- `scripts/gimmicks/visuals/compound_pond_player.gd` attaches the reusable `scripts/axolotl_cutout_preview.gd` rig to this stage's player. Placement derives from the existing texture, CharacterData size/offset and `assets/characters/axolotl_cutout/rig.json` bounds, without shared Resource mutations.
- `resources/compound_pond_physics.tres`: inherited elasticity, collider_size_scale=1.05 and native contact reporting budget=24. The inherited visual response still uses at most four direction groups.
- `contact_release_gap` tunes only the separation tolerance for existing visual contacts. It does not enlarge physical colliders or change their 1.05 scale.
- `resources/compound_pond_polygon_profiles.tres`: centered mask-pixel vertices. Installation applies actual shell transform and 1.05 scale. Generate with `tools/generate_compound_pond_polygons.py` (standard-library Python).
- `resources/visuals/pond_surface_rendering_settings_63.tres`: independent copy of the tuned 62 appearance.
- Collision debug overlay is off by default for 63. Enable `show_collision_debug` in the stage's physics tuning Resource to show mint outlines/faint fills over active colliders and yellow for the preview. Disabled/replaced shapes are excluded. Colors and screen-pixel line width remain configurable. It follows physics transforms without visual warping and is removed with the handler's visual layers.

## Scoped evidence and limits

- Player replacement: the three changed visual/handler scripts passed scoped Godot syntax validation. Neutral pose alignment is calculated from alpha bounds, with preserved aspect ratio; the new silhouette is narrower than the old drawing at the same height. Actual stage appearance, gill seams and skill/hit feedback need user replay; no battle/regression/export run was performed for this change.

- Generator checks strict convexity. Heart/star: 24 vertices each; maximum deviation from the unsimplified convex-hull boundary is 1.950/1.681 source texture pixels, before 1.05 scaling. This is hull approximation error, not the deliberately filled concave regions.
- Godot syntax/preload checks passed for the changed scripts. Resource paths/catalog references are checked only in this mechanic's scope. No gameplay/regression/export run; visual or physical stability has not been proven.
- Contact-continuity revision: scoped Godot syntax checks passed. Thirteen geometry-only analytical cases (including swapped shape order) passed for circle contact/overlap/separation, rectangle edge/corner, capsule side/cap/corner, rotated convex polygon and 0.49/0.51px separation around the release threshold. These ran without a battle or physics simulation; native-report interruption and visible stability still need user replay.
- Polygon edges are straight and the warp remains a visual approximation. Existing authored normal maps are retained.
- Playtest: Does rolling/stacking tremble less? Are the filled heart/star valleys acceptable? Do wall contacts, release and guide endpoints match the visible result? Verify ordinary same-stage merging and compare with untouched 62.
