import Foundation

/// UI-facing language for YMM4MCore diagnostics.
///
/// The setup window (`YMM4MApp` / `Loc`) is fully Japanese/English with
/// compile-time parity. Core-layer errors and progress strings are shown
/// verbatim in the status area, so they must follow the same rule: every
/// user-visible core string exists in both languages. Error types expose
/// `message(for:)` for explicit rendering (and tests); `LocalizedError`
/// conformances delegate to the current locale so existing
/// `error.localizedDescription` call sites become bilingual untouched.
public enum CoreLanguage: String, Sendable, CaseIterable {
    case japanese
    case english

    public static var current: CoreLanguage {
        let preferred = Locale.preferredLanguages.first?.lowercased() ?? "en"
        return preferred.hasPrefix("ja") ? .japanese : .english
    }
}
