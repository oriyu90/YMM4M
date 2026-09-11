import Foundation

public struct Arm64WineFEXBackend: RuntimeBackend {
    public let identifier = "arm64-wine-fex"
    public let supportLevel: RuntimeSupportLevel = .research

    public init() {}

    public func probe() async throws -> RuntimeProbeResult {
        RuntimeProbeResult(
            available: false,
            architecture: "arm64+x86_64",
            runtimePath: nil,
             reason: CoreMessages.researchBackendDisabled()
        )
    }

    public func prepare() async throws { throw RuntimeError.unavailable((try await probe()).reason) }
    public func launch(executable: URL, arguments: [String]) async throws -> RuntimeProcessHandle {
        throw RuntimeError.unavailable((try await probe()).reason)
    }
    public func terminate() async throws {}
    public func collectDiagnostics() async throws -> RuntimeDiagnostics {
        RuntimeDiagnostics(backend: identifier, probe: try await probe(), collectedAt: Date())
    }
}

