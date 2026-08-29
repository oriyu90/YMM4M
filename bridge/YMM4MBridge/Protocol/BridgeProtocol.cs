using System.Buffers.Binary;
using System.Net;
using System.Net.Sockets;
using System.Text.Json;

namespace YMM4M.Bridge.Protocol;

public enum MessageType : byte
{
    Hello = 1, VideoInfo = 2, AudioInfo = 3, VideoFrame = 4,
    AudioChunk = 5, End = 6, Cancel = 7, Error = 8,
}

public sealed record BridgeEndpoint(int Port, string SessionToken, ushort ProtocolVersion = 1)
{
    public IPEndPoint LoopbackEndpoint => new(IPAddress.Loopback, Port);
}

public sealed class BridgeClient : IAsyncDisposable
{
    public const ushort ProtocolVersion = 1;
    public const int MaximumMessageSize = 256 * 1024 * 1024;
    private readonly TcpClient client = new(AddressFamily.InterNetwork);
    private NetworkStream? stream;

    public async Task ConnectAsync(BridgeEndpoint endpoint, CancellationToken cancellationToken)
    {
        if (endpoint.ProtocolVersion != ProtocolVersion)
            throw new InvalidOperationException("YMM4M bridge protocol version mismatch.");
        await client.ConnectAsync(endpoint.LoopbackEndpoint, cancellationToken).ConfigureAwait(false);
        stream = client.GetStream();
        var hello = JsonSerializer.SerializeToUtf8Bytes(new
        {
            protocolVersion = ProtocolVersion,
            sessionToken = endpoint.SessionToken,
        });
        await SendAsync(MessageType.Hello, hello, cancellationToken).ConfigureAwait(false);
    }

    public async Task SendAsync(MessageType type, ReadOnlyMemory<byte> payload, CancellationToken cancellationToken)
    {
        if (stream is null) throw new InvalidOperationException("Bridge is not connected.");
        var messageLength = checked(payload.Length + 1);
        if (messageLength > MaximumMessageSize) throw new ArgumentOutOfRangeException(nameof(payload));
        var header = new byte[5];
        BinaryPrimitives.WriteUInt32BigEndian(header, (uint)messageLength);
        header[4] = (byte)type;
        await stream.WriteAsync(header, cancellationToken).ConfigureAwait(false);
        await stream.WriteAsync(payload, cancellationToken).ConfigureAwait(false);
    }

    public async ValueTask DisposeAsync()
    {
        if (stream is not null) await stream.DisposeAsync().ConfigureAwait(false);
        client.Dispose();
    }
}

