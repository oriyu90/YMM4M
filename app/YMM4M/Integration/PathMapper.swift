import Darwin
import Foundation

public struct PathMapper: Sendable {
    public let mediaRoot: URL

    public init(mediaRoot: URL) {
        self.mediaRoot = mediaRoot.standardizedFileURL.resolvingSymlinksInPath()
    }

    public func winePath(for fileURL: URL) throws -> String {
        guard fileURL.isFileURL else { throw PathMappingError.notAFileURL }
        let root = mediaRoot.path
        let file = fileURL.standardizedFileURL.resolvingSymlinksInPath().path
        guard file == root || file.hasPrefix(root + "/") else {
            throw PathMappingError.outsideMediaRoot
        }
        let relative = file == root ? "" : String(file.dropFirst(root.count + 1))
        guard !relative.contains("\\") else { throw PathMappingError.unrepresentablePath }
        return "M:\\" + relative.replacingOccurrences(of: "/", with: "\\")
    }
}

public enum PathMappingError: LocalizedError, Equatable {
    case notAFileURL
    case outsideMediaRoot
    case unrepresentablePath

    public func message(for language: CoreLanguage) -> String {
        switch self {
        case .notAFileURL:
            switch language {
            case .japanese: return "Finderから受け取った対象がローカルファイルではありません。"
            case .english: return "The item received from Finder is not a local file."
            }
        case .outsideMediaRoot:
            switch language {
            case .japanese: return "ファイルは選択したMedia Rootの外側にあります。"
            case .english: return "The file is outside the selected media root."
            }
        case .unrepresentablePath:
            switch language {
            case .japanese: return "ファイル名にWineパスとして安全に表現できない文字が含まれています。"
            case .english: return "The file name contains characters that cannot be safely represented as a Wine path."
            }
        }
    }

    public var errorDescription: String? {
        message(for: CoreLanguage.current)
    }
}

public enum WineMediaDriveError: LocalizedError, Equatable {
    case missingPrefix
    case missingMediaRoot
    case missingDosDevices
    case conflictingMapping(String)

    public func message(for language: CoreLanguage) -> String {
        switch self {
        case .missingPrefix:
            switch language {
            case .japanese: return "専用Wineプレフィックがありません。"
            case .english: return "The dedicated Wine prefix is missing."
            }
        case .missingMediaRoot:
            switch language {
            case .japanese: return "選択したMedia Rootがありません。"
            case .english: return "The selected media root is missing."
            }
        case .missingDosDevices:
            switch language {
            case .japanese: return "Wineプレフィックのdosdevicesがありません。"
            case .english: return "The Wine prefix has no dosdevices directory."
            }
        case .conflictingMapping(let destination):
            switch language {
            case .japanese: return "M:は別の場所に割り当て済みです: \(destination)"
            case .english: return "M: is already mapped to another location: \(destination)"
            }
        }
    }

    public var errorDescription: String? {
        message(for: CoreLanguage.current)
    }
}

public struct WineMediaDrive: Sendable {
    public static func configure(
        prefix: URL,
        mediaRoot: URL,
        replaceExistingMapping: Bool = false
    ) throws {
        let manager = FileManager.default
        let canonicalPrefix = prefix.standardizedFileURL.resolvingSymlinksInPath()
        let canonicalRoot = mediaRoot.standardizedFileURL.resolvingSymlinksInPath()
        guard isDirectory(canonicalPrefix, manager: manager) else {
            throw WineMediaDriveError.missingPrefix
        }
        guard isDirectory(canonicalRoot, manager: manager) else {
            throw WineMediaDriveError.missingMediaRoot
        }

        let dosDevices = canonicalPrefix.appendingPathComponent("dosdevices", isDirectory: true)
        guard isDirectory(dosDevices, manager: manager) else {
            throw WineMediaDriveError.missingDosDevices
        }
        let mapping = dosDevices.appendingPathComponent("m:")

        if let destination = try? manager.destinationOfSymbolicLink(atPath: mapping.path) {
            let destinationURL: URL
            if destination.hasPrefix("/") {
                destinationURL = URL(fileURLWithPath: destination)
            } else {
                destinationURL = URL(fileURLWithPath: destination, relativeTo: dosDevices)
            }
            if destinationURL.standardizedFileURL.resolvingSymlinksInPath() == canonicalRoot {
                return
            }
            if replaceExistingMapping {
                let temporary = dosDevices.appendingPathComponent(".m-\(UUID().uuidString)")
                try manager.createSymbolicLink(at: temporary, withDestinationURL: canonicalRoot)
                defer { try? manager.removeItem(at: temporary) }
                let result = temporary.path.withCString { source in
                    mapping.path.withCString { destination in rename(source, destination) }
                }
                guard result == 0 else {
                    throw WineMediaDriveError.conflictingMapping(destination)
                }
                return
            }
            throw WineMediaDriveError.conflictingMapping(destination)
        }

        if manager.fileExists(atPath: mapping.path) {
            throw WineMediaDriveError.conflictingMapping(mapping.path)
        }
        try manager.createSymbolicLink(at: mapping, withDestinationURL: canonicalRoot)
    }

    private static func isDirectory(_ url: URL, manager: FileManager) -> Bool {
        var isDirectory: ObjCBool = false
        return manager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }
}
