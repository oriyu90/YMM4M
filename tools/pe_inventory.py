#!/usr/bin/env python3
"""Small dependency-free PE metadata reader; it never loads executable code."""
from __future__ import annotations

import hashlib
import io
import struct
from dataclasses import dataclass

MACHINES = {0x014C: "I386", 0x8664: "AMD64", 0xAA64: "ARM64", 0xA641: "ARM64EC"}
SUBSYSTEMS = {2: "WINDOWS_GUI", 3: "WINDOWS_CUI"}


@dataclass(frozen=True)
class PEInfo:
    size: int
    sha256: str
    machine: str
    machineCode: str
    subsystem: str
    managed: bool

    def as_dict(self) -> dict[str, object]:
        return {
            "size": self.size,
            "sha256": self.sha256,
            "machine": self.machine,
            "machineCode": self.machineCode,
            "subsystem": self.subsystem,
            "managed": self.managed,
        }


def inspect_bytes(data: bytes) -> PEInfo:
    if len(data) < 0x40 or data[:2] != b"MZ":
        raise ValueError("not a PE file: missing MZ header")
    pe_offset = struct.unpack_from("<I", data, 0x3C)[0]
    if pe_offset + 24 > len(data) or data[pe_offset:pe_offset + 4] != b"PE\0\0":
        raise ValueError("not a PE file: missing PE signature")
    machine, _, _, _, _, optional_size, _ = struct.unpack_from("<HHIIIHH", data, pe_offset + 4)
    optional = pe_offset + 24
    if optional + optional_size > len(data):
        raise ValueError("truncated optional header")
    magic = struct.unpack_from("<H", data, optional)[0]
    if magic == 0x10B:
        subsystem_offset, directories_offset = optional + 68, optional + 96
    elif magic == 0x20B:
        subsystem_offset, directories_offset = optional + 68, optional + 112
    else:
        raise ValueError(f"unknown optional header magic 0x{magic:04x}")
    subsystem = struct.unpack_from("<H", data, subsystem_offset)[0]
    clr_directory = directories_offset + (14 * 8)
    managed = False
    if clr_directory + 8 <= optional + optional_size:
        clr_rva, clr_size = struct.unpack_from("<II", data, clr_directory)
        managed = clr_rva != 0 and clr_size != 0
    return PEInfo(
        size=len(data), sha256=hashlib.sha256(data).hexdigest(),
        machine=MACHINES.get(machine, "UNKNOWN"), machineCode=f"0x{machine:04x}",
        subsystem=SUBSYSTEMS.get(subsystem, f"UNKNOWN_{subsystem}"), managed=managed,
    )


def inspect_stream(stream: io.BufferedIOBase) -> PEInfo:
    return inspect_bytes(stream.read())

