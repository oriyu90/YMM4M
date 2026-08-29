import Foundation

public struct LaunchConfiguration: Codable, Equatable, Sendable {
    public enum UIProfile: String, Codable, CaseIterable, Sendable {
        case wpfSoftware = "wpf-software"
        case wineD3DVulkan = "wined3d-vulkan"
        case wineD3DOpenGL = "wined3d-opengl"
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

