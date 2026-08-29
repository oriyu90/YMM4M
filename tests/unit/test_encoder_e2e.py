from __future__ import annotations

import json
import socket
import struct
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ENCODER = ROOT / ".build" / "debug" / "YMM4MEncoder"


def message(kind: int, payload: bytes = b"") -> bytes:
    return struct.pack(">I", len(payload) + 1) + bytes([kind]) + payload


@unittest.skipUnless(ENCODER.exists(), "build YMM4MEncoder before integration test")
class EncoderEndToEndTests(unittest.TestCase):
    def test_authenticated_raw_capture(self):
        token = "a" * 64
        with tempfile.TemporaryDirectory() as directory:
            process = subprocess.Popen(
                [str(ENCODER), "--token", token, "--output-directory", directory],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            )
            assert process.stdout is not None
            ready = json.loads(process.stdout.readline())
            self.assertEqual(ready["host"], "127.0.0.1")
            with socket.create_connection((ready["host"], int(ready["port"])), timeout=5) as client:
                hello = json.dumps({"protocolVersion": 1, "sessionToken": token}, separators=(",", ":")).encode()
                client.sendall(message(1, hello))
                client.sendall(message(2, b'{"pixelFormat":"UNKNOWN"}'))
                client.sendall(message(3, b'{"sampleFormat":"UNKNOWN"}'))
                client.sendall(message(4, b"video-frame"))
                client.sendall(message(5, b"audio-chunk"))
                client.sendall(message(6))
            _, stderr = process.communicate(timeout=5)
            self.assertEqual(process.returncode, 0, stderr)
            output = Path(directory)
            self.assertEqual((output / "video.raw").read_bytes(), b"video-frame")
            self.assertEqual((output / "audio.raw").read_bytes(), b"audio-chunk")

    def test_rejects_bad_token_without_writing_output(self):
        with tempfile.TemporaryDirectory() as directory:
            process = subprocess.Popen(
                [str(ENCODER), "--token", "a" * 64, "--output-directory", directory],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            )
            assert process.stdout is not None
            ready = json.loads(process.stdout.readline())
            with socket.create_connection((ready["host"], int(ready["port"])), timeout=5) as client:
                hello = json.dumps({"protocolVersion": 1, "sessionToken": "b" * 64}, separators=(",", ":")).encode()
                client.sendall(message(1, hello))
            _, stderr = process.communicate(timeout=5)
            self.assertEqual(process.returncode, 2)
            self.assertIn("authentication failed", stderr)
            self.assertEqual(list(Path(directory).iterdir()), [])


if __name__ == "__main__":
    unittest.main()
