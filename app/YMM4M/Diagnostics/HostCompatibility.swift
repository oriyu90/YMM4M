import Foundation

/// Host-OS support surface for YMM4M.
///
/// YMM4M is validated on macOS 26 (Tahoe) on Apple Silicon: `Package.swift`
/// targets `.macOS("26.0")` and `Info.plist` sets `LSMinimumSystemVersion`
/// 26.0, so older systems are refused at launch. A *newer* major release is
/// not refused — Apple has announced Intel-translation changes after the 26
/// series — but it must never boot silently as if it were validated.
/// `untestedOSNotice` returns a short bilingual notice for any non-26 host,
/// and nil on the validated surface, so the UI can inform without blocking.
public enum HostCompatibility {
    public static let validatedMajorOSVersion = 26

    public static func untestedOSNotice(
        osVersion: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion,
        language: CoreLanguage = .current
    ) -> String? {
        guard osVersion.majorVersion != validatedMajorOSVersion else { return nil }
        switch language {
        case .japanese:
            return "注意: このmacOS \(osVersion.majorVersion) はYMM4Mの動作検証対象外です。Rosettaの扱いが変わっている可能性があり、互換環境の新規構築はmacOS 26のMacで行うことを推奨します。"
        case .english:
            return "Note: macOS \(osVersion.majorVersion) is outside YMM4M's validated surface. Rosetta behavior may have changed; building the compatibility environment on a macOS 26 Mac is recommended."
        }
    }
}
