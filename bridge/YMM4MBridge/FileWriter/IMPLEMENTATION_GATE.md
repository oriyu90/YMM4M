# FileWriter implementation gate

The YMM4 `IVideoFileWriterPlugin` adapter is intentionally not implemented yet.

Before adding it, record all of the following from the public YMM4 v4.55.1.1 plugin assemblies or an approved black-box writer test:

- exact referenced assembly paths and hashes;
- `VideoInfo` member semantics;
- `WriteVideo(byte[])` pixel order, stride, orientation, and alpha convention;
- `WriteAudio(float[])` channel interleaving, sample range, and chunk timing;
- cancellation and finalization behavior.

Do not guess these values. The transport in `Protocol/BridgeProtocol.cs` can carry the validated byte arrays unchanged once the gate is complete.

