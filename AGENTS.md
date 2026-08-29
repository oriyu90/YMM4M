# Repository rules

1. Never guess undocumented YMM4 behavior.
2. Record evidence before changing compatibility code.
3. Do not decompile proprietary YMM4 implementation without explicit legal review.
4. Never commit YMM4 binaries.
5. Never commit proprietary Microsoft runtimes or fonts without verified redistribution rights.
6. Do not treat DXMT as MIT or distribute CrossOver.
7. Do not depend permanently on Rosetta, disable SIP, or disable Gatekeeper globally.
8. Separate WPF, D3D11, D3D12, and WebView2 issues.
9. Prefer FFmpeg and official YMM4 plugin APIs over binary patching.
10. Every workaround and compatibility claim needs evidence and a reproducible test.
11. Do not modify a user's project silently.
12. Keep the native macOS host ARM64 and Wine patches small and upstreamable.

## Required project context

- Before continuing development, read `COMMON_RULES.md` and `NEXT_SESSION_HANDOFF.md`.
- Treat `compatibility/features.yaml` as the machine-readable current result and `STATUS.md` as the human-readable status. Historical passes do not override a newer current-state failure.
- The release audit document `YMM4M ライセンス監査・実装判断指示.md` is intentionally deferred by the user. Do not open or execute it during ordinary development; read and follow it only at the final pre-release gate.
