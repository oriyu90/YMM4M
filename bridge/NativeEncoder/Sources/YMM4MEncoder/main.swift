import Darwin
import Foundation
import YMM4MProtocol

enum EncoderError: LocalizedError {
    case usage
    case invalidOutputDirectory
    case socket(String)
    case disconnected
    case authentication
    case protocolMismatch

    var errorDescription: String? {
        switch self {
        case .usage: "Usage: YMM4MEncoder --token <random-token> --output-directory <existing-directory> [--port 0]"
        case .invalidOutputDirectory: "Output directory must already exist and be a directory."
        case .socket(let operation): "Socket operation failed: \(operation) (errno \(errno))"
        case .disconnected: "Bridge disconnected before END."
        case .authentication: "Bridge authentication failed."
        case .protocolMismatch: "Bridge protocol version mismatch."
        }
    }
}

struct Arguments {
    let token: String
    let outputDirectory: URL
    let port: UInt16

    init(_ values: [String]) throws {
        func value(after flag: String) -> String? {
            guard let index = values.firstIndex(of: flag), values.indices.contains(index + 1) else { return nil }
            return values[index + 1]
        }
        guard let token = value(after: "--token"), token.count >= 32,
              let output = value(after: "--output-directory") else { throw EncoderError.usage }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: output, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw EncoderError.invalidOutputDirectory
        }
        self.token = token
        self.outputDirectory = URL(fileURLWithPath: output, isDirectory: true).standardizedFileURL
        self.port = UInt16(value(after: "--port") ?? "0") ?? 0
    }
}

final class RawReceiver {
    private let arguments: Arguments
    private var videoHandle: FileHandle?
    private var audioHandle: FileHandle?

    init(arguments: Arguments) { self.arguments = arguments }

    func run() throws {
        let server = socket(AF_INET, SOCK_STREAM, 0)
        guard server >= 0 else { throw EncoderError.socket("socket") }
        defer { close(server) }

        var reuse: Int32 = 1
        setsockopt(server, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout.size(ofValue: reuse)))
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = arguments.port.bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))
        let bindResult = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(server, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else { throw EncoderError.socket("bind") }
        guard listen(server, 1) == 0 else { throw EncoderError.socket("listen") }

        var actual = sockaddr_in()
        var actualLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutablePointer(to: &actual) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                _ = getsockname(server, $0, &actualLength)
            }
        }
        let ready = ["host": "127.0.0.1", "port": String(UInt16(bigEndian: actual.sin_port)), "protocolVersion": String(BridgeProtocol.version)]
        let readyData = try JSONSerialization.data(withJSONObject: ready, options: [.sortedKeys])
        FileHandle.standardOutput.write(readyData + Data("\n".utf8))

        let client = accept(server, nil, nil)
        guard client >= 0 else { throw EncoderError.socket("accept") }
        defer { close(client) }
        try receiveMessages(from: client)
    }

    private func receiveMessages(from socket: Int32) throws {
        var authenticated = false
        while true {
            let header = try readExactly(4, from: socket)
            let length = header.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            guard length >= 1, length <= BridgeProtocol.maximumMessageSize else {
                throw BridgeProtocol.ProtocolError.invalidLength(Int(length))
            }
            let body = try readExactly(Int(length), from: socket)
            let envelope = try BridgeProtocol.decode(header + body)

            if !authenticated {
                guard envelope.type == .hello else { throw EncoderError.authentication }
                let hello = try JSONDecoder().decode(BridgeProtocol.Hello.self, from: envelope.payload)
                guard hello.protocolVersion == BridgeProtocol.version else { throw EncoderError.protocolMismatch }
                guard constantTimeEqual(hello.sessionToken, arguments.token) else { throw EncoderError.authentication }
                authenticated = true
                continue
            }

            switch envelope.type {
            case .videoInfo:
                try envelope.payload.write(to: arguments.outputDirectory.appendingPathComponent("video-info.json"), options: .atomic)
            case .audioInfo:
                try envelope.payload.write(to: arguments.outputDirectory.appendingPathComponent("audio-info.json"), options: .atomic)
            case .videoFrame:
                try append(envelope.payload, named: "video.raw", handle: &videoHandle)
            case .audioChunk:
                try append(envelope.payload, named: "audio.raw", handle: &audioHandle)
            case .end:
                try videoHandle?.close()
                try audioHandle?.close()
                return
            case .cancel:
                try videoHandle?.close()
                try audioHandle?.close()
                return
            case .hello, .error:
                continue
            }
        }
    }

    private func append(_ data: Data, named name: String, handle: inout FileHandle?) throws {
        if handle == nil {
            let url = arguments.outputDirectory.appendingPathComponent(name)
            FileManager.default.createFile(atPath: url.path, contents: nil)
            handle = try FileHandle(forWritingTo: url)
        }
        try handle?.write(contentsOf: data)
    }

    private func readExactly(_ count: Int, from socket: Int32) throws -> Data {
        var data = Data(count: count)
        var offset = 0
        while offset < count {
            let received = data.withUnsafeMutableBytes { buffer in
                Darwin.read(socket, buffer.baseAddress!.advanced(by: offset), count - offset)
            }
            guard received > 0 else { throw EncoderError.disconnected }
            offset += received
        }
        return data
    }

    private func constantTimeEqual(_ lhs: String, _ rhs: String) -> Bool {
        let a = Array(lhs.utf8)
        let b = Array(rhs.utf8)
        var difference = UInt8(truncatingIfNeeded: a.count ^ b.count)
        for index in 0..<max(a.count, b.count) {
            difference |= (index < a.count ? a[index] : 0) ^ (index < b.count ? b[index] : 0)
        }
        return difference == 0
    }
}

do {
    let arguments = try Arguments(Array(CommandLine.arguments.dropFirst()))
    try RawReceiver(arguments: arguments).run()
} catch {
    FileHandle.standardError.write(Data("YMM4MEncoder: \(error.localizedDescription)\n".utf8))
    exit(2)
}

