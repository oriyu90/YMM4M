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
}

