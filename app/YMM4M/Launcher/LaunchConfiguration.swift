import Foundation

public struct LaunchConfiguration: Codable, Equatable, Sendable {
    /// The compatibility runtime is built `--without-vulkan` and without X11, so
    /// `wined3d-vulkan` / `wined3d-opengl` could never succeed and have been
    /// removed. WPF is forced onto its software rasterizer through the required
    /// `Avalon.Graphics\DisableHWAcceleration` prefix profile; editing/preview
    /// still reach Metal through the source-patched DXMT path.
    public enum UIProfile: String, Codable, CaseIterable, Sendable {
        case wpfSoftware = "wpf-software"
    }

    public var ymm4Executable: URL?
    public var mediaRoot: URL?
    public var uiProfile: UIProfile
    public var launchWithoutThirdPartyPlugins: Bool

    public init(
        ymm4Executable: URL? = nil,
        mediaRoot: URL? = nil,
        uiProfile: UIProfile = .wpfSoftware,
        launchWithoutThirdPartyPlugins: Bool = false
    ) {
        self.ymm4Executable = ymm4Executable
        self.mediaRoot = mediaRoot
        self.uiProfile = uiProfile
        self.launchWithoutThirdPartyPlugins = launchWithoutThirdPartyPlugins
    }

    // A configuration persisted by an older build may still name the removed
    // `wined3d-vulkan` / `wined3d-opengl` profiles. Decode those as the only
    // supported profile instead of throwing.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ymm4Executable = try container.decodeIfPresent(URL.self, forKey: .ymm4Executable)
        mediaRoot = try container.decodeIfPresent(URL.self, forKey: .mediaRoot)
        let rawProfile = try container.decodeIfPresent(String.self, forKey: .uiProfile)
        uiProfile = rawProfile.flatMap(UIProfile.init(rawValue:)) ?? .wpfSoftware
        launchWithoutThirdPartyPlugins = try container.decodeIfPresent(
            Bool.self, forKey: .launchWithoutThirdPartyPlugins
        ) ?? false
    }
}

