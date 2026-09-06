#!/bin/sh
# Finalize a staged schema-2 clean-runtime manifest after the compatibility
# fixture gate has passed against that exact runtime + a dedicated prefix.
#
#   YMM4M_RUNTIME_ROOT=/abs/path/to/runtime \
#   YMM4M_FIXTURE_DIR=/abs/path/to/tests/fixtures \
#     tools/finalize-runtime-gate.sh
#
# It records `provenance.gate.fixtures` (SHA-256 of the eight gate fixture
# sources) and flips `provenance.gate.results` to pass. It refuses to touch a
# manifest that is not schema 2, that already has a non-pending result, or whose
# recorded runtime file hashes do not match the manifest's own `files` block.
set -eu

: "${YMM4M_RUNTIME_ROOT:?Set YMM4M_RUNTIME_ROOT to the staged runtime directory}"
: "${YMM4M_FIXTURE_DIR:?Set YMM4M_FIXTURE_DIR to the repository tests/fixtures directory}"

manifest="$YMM4M_RUNTIME_ROOT/ymm4m-runtime.json"
test -f "$manifest" || { echo "runtime manifest not found: $manifest" >&2; exit 2; }
test -d "$YMM4M_FIXTURE_DIR" || { echo "fixture dir not found: $YMM4M_FIXTURE_DIR" >&2; exit 2; }

/usr/bin/env YMM4M_RUNTIME_ROOT="$YMM4M_RUNTIME_ROOT" \
             YMM4M_FIXTURE_DIR="$YMM4M_FIXTURE_DIR" \
  /usr/bin/python3 - <<'PY'
import hashlib
import json
import os
import sys

root = os.environ["YMM4M_RUNTIME_ROOT"]
fixture_dir = os.environ["YMM4M_FIXTURE_DIR"]
manifest_path = os.path.join(root, "ymm4m-runtime.json")

GATE_FIXTURES = [
    "d3d11-compute-pipeline-reproducer.cpp",
    "d3d11-context-state-reproducer.cpp",
    "dxgi-surface2-reproducer.cpp",
    "d2d-device6-reproducer.cpp",
    "d2d-null-effect-input-reproducer.cpp",
    "d2d-3d-transform-reproducer.cpp",
    "d2d-japanese-text-reproducer.cpp",
    "dwrite-font-fallback-reproducer.cpp",
]


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def macho_loadable_sha256(path):
    """Port of RosettaWineBackend.machOLoadableSHA256: zero the LC_UUID payload
    and hash the bytes before the __LINKEDIT segment's file offset."""
    data = bytearray(open(path, "rb").read())

    def u32(off):
        if off < 0 or off + 4 > len(data):
            sys.exit("winemac.so Mach-O structure is invalid")
        return int.from_bytes(data[off:off + 4], "little")

    def u64(off):
        if off < 0 or off + 8 > len(data):
            sys.exit("winemac.so Mach-O structure is invalid")
        return int.from_bytes(data[off:off + 8], "little")

    if u32(0) != 0xFEEDFACF or u32(4) != 0x01000007:
        sys.exit("winemac.so is not an x86_64 Mach-O")
    ncmds = u32(16)
    offset = 32
    linkedit_off = None
    for _ in range(ncmds):
        cmd = u32(offset)
        size = u32(offset + 4)
        if size < 8 or offset + size > len(data):
            sys.exit("winemac.so load command is invalid")
        if cmd == 0x1B:  # LC_UUID
            if size < 24:
                sys.exit("winemac.so LC_UUID is invalid")
            data[offset + 8:offset + 24] = b"\x00" * 16
        elif cmd == 0x19 and size >= 72:  # LC_SEGMENT_64
            name = bytes(data[offset + 8:offset + 24]).split(b"\x00", 1)[0]
            if name == b"__LINKEDIT":
                linkedit_off = u64(offset + 40)
        offset += size
    if linkedit_off is None or linkedit_off < offset or linkedit_off > len(data):
        sys.exit("winemac.so has no valid __LINKEDIT")
    return hashlib.sha256(bytes(data[:linkedit_off])).hexdigest()


manifest = json.load(open(manifest_path))
if manifest.get("schema") != 2:
    sys.exit("refusing to finalize a manifest that is not schema 2")
provenance = manifest.get("provenance") or {}
gate = provenance.get("gate") or {}
results = gate.get("results") or {}
if results.get("fixtures") not in (None, "pending") or results.get("compute100") not in (None, "pending"):
    sys.exit("gate results are already finalized; not overwriting")

# The gate ran against exactly the binaries the manifest lists.
files = manifest.get("files") or {}
for rel, recorded in files.items():
    actual = sha256_file(os.path.join(root, rel))
    if actual != recorded:
        sys.exit(f"runtime file changed since staging: {rel}")
if gate.get("runtimeFiles") != files:
    sys.exit("gate runtimeFiles does not match the manifest files block")

fixtures = {}
for name in GATE_FIXTURES:
    path = os.path.join(fixture_dir, name)
    if not os.path.isfile(path):
        sys.exit(f"missing gate fixture source: {path}")
    fixtures[f"tests/fixtures/{name}"] = sha256_file(path)

winemac_rel = "lib/wine/x86_64-unix/winemac.so"
if winemac_rel not in files:
    sys.exit("manifest files block is missing winemac.so")
gate["winemacLoadableSha256"] = macho_loadable_sha256(os.path.join(root, winemac_rel))
gate["fixtures"] = fixtures
gate["results"] = {"fixtures": "pass", "compute100": "pass"}
provenance["gate"] = gate
manifest["provenance"] = provenance

tmp = manifest_path + ".part"
with open(tmp, "w") as handle:
    json.dump(manifest, handle, indent=2, sort_keys=True)
    handle.write("\n")
os.replace(tmp, manifest_path)
print(f"finalized runtime fixture gate: {manifest_path}")
PY
