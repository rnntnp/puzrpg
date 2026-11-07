# QuarkPhysics 1.0.7

## Active runtime

- Stage 60 uses standard independent polygon particles and official binaries. Windows x64 release DLL SHA-256: 5f7143c45a517544ecdbd32607c7ee449df5b5315858c0bb1e3f1a640fd30219. It has no bind_material method. Both Windows x64 manifest configurations select this release binary. Scoped runtime tested with Godot 4.7.1; other platforms untested.
- The modified source below is retained as historical experiment source, not the source of the active official DLL. Building it would re-enable the optional extension; stage 60 does not call that API.

## Historical modified six-control build

- Official distribution: https://store.godotengine.org/asset/eray-zesen/quarkphysics/download/690/
- Source: https://github.com/erayzesen/godot-quarkphysics/tree/v1.0.7
- MIT license in LICENSE; upstream source headers retained.
- Original ZIP SHA-256: a9f481021010bbb28716419be608d54a3e67daf330b9a5bfdf43184fb613f23b.
- Source vendored in native/src. Optional affine boundary binding scatters position/velocity contact corrections to six drivers and caches dependent geometry. Bound particles skip independent integration and shape matching. For the six-control dense polygon, area preservation solves the combined six-driver area gradients; it avoids unbalanced translation from separate boundary pressure scattering. Stock unbound particles retain original paths. Modified upstream files: QuarkPhysics/qparticle.h, qparticle.cpp, qsoftbody.cpp, qbody.h/cpp, qmanifold.h/cpp; qparticle_object.h/cpp. Bound contacts refresh penetration after driver movement, split response by effective inverse mass and apply friction to velocity.
- Windows x64 release DLL built using MSVC 14.51, SCons 4.11.1 and godot-cpp tag godot-4.5-stable. SHA-256: cf20e1f0e471b0d9b2ea15aa080f537b1dfb160d408f08f77c0d9205901592e9. Both Windows x64 manifest configurations use this optimized DLL. Tested with Godot 4.7.1.
- Other supplied binaries are unchanged official binaries and untested; stage 60 falls back to XPBD when binding API is absent. Rebuild other platforms to use the modified Quark backend.
- Reproduce from native: scons godot_cpp_dir=/path/to/godot-cpp platform=windows target=template_release arch=x86_64 -j16. Pin godot-cpp to godot-4.5-stable. Build artifacts ignored; examples/editor mesh plugin omitted.
