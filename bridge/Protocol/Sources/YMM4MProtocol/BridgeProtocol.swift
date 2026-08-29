import Foundation

public enum BridgeProtocol {
    public static let version: UInt16 = 1
    public static let maximumMessageSize = 256 * 1024 * 1024

    public enum MessageType: UInt8, Codable, Sendable {
        case hello = 1
        case videoInfo = 2
        case audioInfo = 3
        case videoFrame = 4
        case audioChunk = 5
        case end = 6
        case cancel = 7
        case error = 8
    }

    public struct Envelope: Equatable, Sendable {
        public let type: MessageType
        public let payload: Data

        public init(type: MessageType, payload: Data = Data()) {
            self.type = type
            self.payload = payload
        }
    }

    public struct Hello: Codable, Equatable, Sendable {
        public let protocolVersion: UInt16
        public let sessionToken: String

        public init(protocolVersion: UInt16 = BridgeProtocol.version, sessionToken: String) {
            self.protocolVersion = protocolVersion
            self.sessionToken = sessionToken
        }
    }

    public struct VideoInfo: Codable, Equatable, Sendable {
        public let width: Int
        public let height: Int
        public let fpsNumerator: Int
        public let fpsDenominator: Int
        public let pixelFormat: String
        public let stride: Int
    }

    public struct AudioInfo: Codable, Equatable, Sendable {
        public let sampleRate: Int
        public let channelCount: Int
        public let sampleFormat: String
    }

    public enum ProtocolError: Error, Equatable {
        case incompleteHeader
        case invalidLength(Int)
        case unknownMessageType(UInt8)
        case incompletePayload(expected: Int, actual: Int)
    }

    public static func encode(_ envelope: Envelope) throws -> Data {
        let bodyLength = envelope.payload.count + 1
        guard bodyLength <= maximumMessageSize else { throw ProtocolError.invalidLength(bodyLength) }
        var length = UInt32(bodyLength).bigEndian
        var output = Data(bytes: &length, count: MemoryLayout<UInt32>.size)
        output.append(envelope.type.rawValue)
        output.append(envelope.payload)
        return output
    }

    public static func decode(_ data: Data) throws -> Envelope {
        guard data.count >= 4 else { throw ProtocolError.incompleteHeader }
        let length = data.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        let bodyLength = Int(length)
        guard bodyLength >= 1, bodyLength <= maximumMessageSize else {
            throw ProtocolError.invalidLength(bodyLength)
        }
        guard data.count - 4 >= bodyLength else {
            throw ProtocolError.incompletePayload(expected: bodyLength, actual: data.count - 4)
        }
        let rawType = data[data.startIndex + 4]
        guard let type = MessageType(rawValue: rawType) else {
            throw ProtocolError.unknownMessageType(rawType)
        }
        return Envelope(type: type, payload: data.subdata(in: 5..<(4 + bodyLength)))
    }

    public static func jsonPayload<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }
}

