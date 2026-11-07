# XPBD pond numerical kernels

Project-owned C++ port of numerical hot loops in `scripts/gimmicks/visuals/soft_pond_layer.gd`, used only by stage 61. The GDScript reference remains intact. This is not QuarkPhysics and does not replace its binary.

Native loops: batched constraint iterations, distance/area constraints, silhouette reconstruction and bounds, contact support/gradients, wall and pair contact projection. Narrow phase still calls the same Godot convex-shape query. Lifecycle, integration, collision candidate generation, velocity damping, sleep, gameplay and rendering remain in the existing GDScript solver. Wall notifications call the inherited gameplay method in their original order.

The native batch imports pairs and masses once per substep. Typed `PairState` records cache contact normals/weights and invariant denominator/approach allowance; gameplay contacts are recorded once per pair per substep rather than once per iteration. Exported manifold Dictionaries remain for the GDScript damping/energy pass, and particle/wall state still uses Dictionaries. Stage 61's candidate override uses stored silhouette envelope circles and configured spatial cells. Do not reuse the contact-invariant cache if future code changes masses or velocities inside the iteration loop without invalidating it.

Reduced pair-query polygons are sampled uniformly with an even vertex count. Native wall support and pair-correction weights retain the dense original bindings to reduce the resting-contact jitter introduced by decimating support geometry. Only query/guide geometry is coarse; rendered meshes and six physical controls retain their original resolution. The native layer's fallback uses full original collision/support geometry.

Windows x64 release DLL is included. Other platforms use the reference fallback. Build with SCons, MSVC and godot-cpp 4.5-stable:

```
scons -C addons/xpbd_pond/native godot_cpp_dir=<absolute-godot-cpp-path> platform=windows target=template_release arch=x86_64 -j16
```

No fast-math: keep double scalar arithmetic and Godot float vectors/packed arrays, original loop order, contact thresholds and constraint parameters. In particular, promote `get_mass()` to double before division. Run `tools/compare_soft_pond.gd` with XPBD and XPBDNative candidates after edits; time with `tools/benchmark_native_xpbd.gd`. Stop the game before replacing the DLL.
