import Foundation

public struct YMM4OfficialAssetReceipt: Equatable, Sendable {
    public let version: String
    public let edition: YMM4Edition
    public let tag: String
    public let assetName: String
    public let assetSize: Int64
    public let archiveSha256: String
    public let sourceRepository: String

    public init(
        version: String,
        edition: YMM4Edition,
        tag: String,
        assetName: String,
        assetSize: Int64,
        archiveSha256: String,
        sourceRepository: String
    ) {
        self.version = version
        self.edition = edition
        self.tag = tag
        self.assetName = assetName
        self.assetSize = assetSize
        self.archiveSha256 = archiveSha256
        self.sourceRepository = sourceRepository
    }
}

public enum YMM4OfficialReleaseVerifier {
    private static let repository = "manju-summoner/YukkuriMovieMaker4"
    private static let maximumMetadataBytes = 2 * 1_024 * 1_024

    public static func verify(archive: URL) async throws -> YMM4OfficialAssetReceipt {
        let identity = try archiveIdentity(archive.lastPathComponent)
        let endpoint = URL(string:
            "https://api.github.com/repos/\(repository)/releases/tags/v\(identity.version)"
        )!
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("YMM4M/0.1", forHTTPHeaderField: "User-Agent")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.httpAdditionalHeaders = [:]
        let (data, response) = try await URLSession(configuration: configuration).data(for: request)
        guard data.count <= maximumMetadataBytes,
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              http.url?.scheme == "https",
              http.url?.host == "api.github.com" else {
            throw RuntimeError.unavailable(CoreMessages.officialReleaseUnverifiable())
        }
        return try verify(archive: archive, releaseMetadata: data)
    }

    public static func verify(
        archive: URL,
        releaseMetadata data: Data
    ) throws -> YMM4OfficialAssetReceipt {
        let identity = try archiveIdentity(archive.lastPathComponent)
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        guard !release.draft,
              !release.prerelease,
              release.tagName == "v\(identity.version)",
              let asset = release.assets.first(where: { $0.name == archive.lastPathComponent }),
              asset.size > 0,
              let digest = asset.digest,
              digest.hasPrefix("sha256:") else {
            throw RuntimeError.unavailable(CoreMessages.archiveNotStableAsset())
        }
        let expectedHash = String(digest.dropFirst("sha256:".count)).lowercased()
        guard expectedHash.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
            throw RuntimeError.unavailable(CoreMessages.officialDigestMalformed())
        }
        let values = try archive.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true,
              Int64(values.fileSize ?? -1) == asset.size else {
            throw RuntimeError.unavailable(CoreMessages.archiveSizeMismatch())
        }
        let actualHash = try YMM4ArchiveInstaller.archiveSHA256(at: archive)
        guard actualHash == expectedHash else {
            throw RuntimeError.unavailable(CoreMessages.archiveDigestMismatch())
        }
        return YMM4OfficialAssetReceipt(
            version: identity.version,
            edition: identity.edition,
            tag: release.tagName,
            assetName: asset.name,
            assetSize: asset.size,
            archiveSha256: actualHash,
            sourceRepository: repository
        )
    }

    private static func archiveIdentity(_ name: String) throws -> (version: String, edition: YMM4Edition) {
        let pattern = #"^YukkuriMovieMaker_v([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)(_Lite)?\.zip$"#
        let expression = try NSRegularExpression(pattern: pattern)
        let range = NSRange(name.startIndex..<name.endIndex, in: name)
        guard let match = expression.firstMatch(in: name, range: range),
              match.range == range,
              let versionRange = Range(match.range(at: 1), in: name) else {
            throw RuntimeError.unavailable(CoreMessages.archiveFileNameChanged())
        }
        return (
            String(name[versionRange]),
            match.range(at: 2).location == NSNotFound ? .standard : .lite
        )
    }

    private struct GitHubRelease: Decodable {
        let tagName: String
        let draft: Bool
        let prerelease: Bool
        let assets: [GitHubAsset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case draft, prerelease, assets
        }
    }

    private struct GitHubAsset: Decodable {
        let name: String
        let size: Int64
        let digest: String?
    }
}
