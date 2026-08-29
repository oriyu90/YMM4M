import Foundation

public struct BridgeSession: Codable, Equatable, Sendable {
    public let host: String
    public let port: UInt16
    public let token: String
    public let protocolVersion: UInt16

    public init(port: UInt16, token: String = BridgeSession.randomToken()) {
        self.host = "127.0.0.1"
        self.port = port
        self.token = token
        self.protocolVersion = 1
    }

    public static func randomToken() -> String {
        (UUID().uuidString + UUID().uuidString).replacingOccurrences(of: "-", with: "").lowercased()
    }
}

