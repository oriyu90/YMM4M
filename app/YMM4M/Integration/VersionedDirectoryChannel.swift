import Darwin
import Foundation

public enum VersionedDirectoryChannel {
    public static func activate(
        store: URL,
        versionDirectory: URL,
        channelName: String = "current"
    ) throws -> URL {
        guard channelName.range(
            of: "^[A-Za-z0-9][A-Za-z0-9._+-]*$", options: .regularExpression
        ) != nil else {
            throw RuntimeError.unavailable("無効なversion channel名です。")
        }
        let manager = FileManager.default
        let resolvedStore = store.standardizedFileURL.resolvingSymlinksInPath()
        let versions = resolvedStore.appendingPathComponent("versions", isDirectory: true)
        let resolvedTarget = versionDirectory.standardizedFileURL.resolvingSymlinksInPath()
        guard resolvedTarget.deletingLastPathComponent() == versions,
              manager.fileExists(atPath: resolvedTarget.path) else {
            throw RuntimeError.unavailable("version保管先の検証に失敗しました。")
        }
        try manager.createDirectory(
            at: resolvedStore,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let channel = resolvedStore.appendingPathComponent(channelName)
        let channelAttributes = try? manager.attributesOfItem(atPath: channel.path)
        if let channelAttributes {
            guard channelAttributes[.type] as? FileAttributeType == .typeSymbolicLink else {
                throw RuntimeError.unavailable("既存のversion channelがsymlinkでないため置き換えません。")
            }
            let existing = channel.resolvingSymlinksInPath()
            guard existing.deletingLastPathComponent() == versions else {
                throw RuntimeError.unavailable("既存のversion channelが専用storeの外を指しています。")
            }
        }
        let temporary = resolvedStore.appendingPathComponent(".\(channelName)-\(UUID().uuidString)")
        try manager.createSymbolicLink(
            atPath: temporary.path,
            withDestinationPath: "versions/\(resolvedTarget.lastPathComponent)"
        )
        defer { try? manager.removeItem(at: temporary) }
        let result = temporary.path.withCString { source in
            channel.path.withCString { destination in rename(source, destination) }
        }
        guard result == 0 else {
            throw RuntimeError.unavailable("version channelのatomic切替に失敗しました。errno=\(errno)")
        }
        return channel
    }
}
