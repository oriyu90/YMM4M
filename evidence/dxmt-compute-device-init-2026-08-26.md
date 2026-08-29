# DXMT compute-pipeline device initialization evidence (2026-08-26)

## Scope

This investigation isolates the intermittent Metal exception previously seen while YMM4 Lite initialized D3D11 compute pipelines:

- `-[__NSCFNumber newComputePipelineStateWithDescriptor:...]: unrecognized selector`
- `-[NSIndirectTaggedPointerString newComputePipelineStateWithDescriptor:...]: unrecognized selector`

The standalone fixture uses documented `D3D11CreateDevice`, `D3DCompile`, compute-shader, dispatch, copy, map, and readback APIs. It does not inspect YMM4 implementation code.

## Reproducer

`tests/fixtures/d3d11-compute-pipeline-reproducer.cpp` creates and destroys a D3D11 device on every iteration, compiles a `cs_5_0` shader, dispatches 256 values, copies the output to a staging buffer, and verifies every value on the CPU.

Before the source fix, the correctly staged diagnostic `winemetal.so` observed 2,700 compute-pipeline calls across 100 iterations:

- valid `AGXG15DDevice`: 2,660
- null device: 40
- other device class: 0

The guarded fallback allowed the test to finish, but it only hid the invalid receiver and was therefore not retained.

## Call-site evidence

Windows- and Unix-side temporary tracing recorded the null calls at the same caller:

- mapped `d3d11.dll` base: `0x6ffffd7d0000`
- caller: `0x6ffffd82a4e2`
- RVA: `0x5a4e2`
- resolved function: `SimpleCommandContext<ArgumentEncodingContext>::getComputePipeline()` in `dxmt_context.cpp`

Source inspection then established the C++ initialization-order defect. `ArgumentEncodingContext::clear_uav_cmd` creates helper compute pipelines during construction, while `device_` and `queue_` were declared later in the class. C++ initializes members in declaration order, so `getComputePipeline()` read `ctx.device_` before its construction. The observed null values and earlier arbitrary Objective-C receiver classes are consistent with that uninitialized read.

## Fix and validation

The fix moves `device_` and `queue_` before the helper-context members in the class declaration and lists them first in the constructor initializer list. No Metal-device substitution remains.

With temporary receiver tracing still enabled, the same 100-iteration test produced:

- valid `AGXG15DDevice`: 2,700
- null device: 0
- other device class: 0
- fallback warnings: 0
- compute/readback failures: 0

After removing all tracing and the fallback, the final candidate again completed 100/100 iterations with verified readback and no Objective-C exception. The combined D3D11, DXGI, Direct2D, and DirectWrite regression suite also passed. YMM4 Lite subsequently remained running through repeated D3D11 initialization on the Japanese test project without either known selector exception.

Development logs:

- `/Users/user/.ymm4m-dev/dxmt-compute-reproducer-100.stderr.log` (before source fix)
- `/Users/user/.ymm4m-dev/dxmt-compute-order-fix-100.stderr.log` (instrumented after source fix)
- `/Users/user/.ymm4m-dev/dxmt-compute-root-fix-100.stdout.log` (final, no fallback or tracing)
- `/Users/user/.ymm4m-dev/runtime-regression-after-compute-fix.log` (combined regression suite)
- `/Users/user/.ymm4m-dev/ymm4-compute-root-fix.stderr.log` (YMM4 Lite runtime path)

## Staging note

CrossOver keeps the DXMT Unix bridge under `lib/dxmt/x86_64-unix` as well as a Wine library directory. Earlier diagnostics had updated only the latter and therefore did not affect the loaded bridge. The final development staging root keeps both copies identical. This staging root remains non-distributable and is evidence only.
