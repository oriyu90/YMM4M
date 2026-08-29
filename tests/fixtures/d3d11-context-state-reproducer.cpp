#define INITGUID
#include <windows.h>
#include <d3d11_1.h>
#include <cstdio>

template <typename T>
static void release(T *object) {
    if (object != nullptr) object->Release();
}

static bool report(const char *operation, HRESULT result) {
    std::printf("%s: 0x%08lx\n", operation, static_cast<unsigned long>(result));
    return SUCCEEDED(result);
}

int main() {
    ID3D11Device *device = nullptr;
    ID3D11Device1 *device1 = nullptr;
    ID3D11DeviceContext *context = nullptr;
    ID3D11DeviceContext1 *context1 = nullptr;
    ID3DDeviceContextState *state = nullptr;
    ID3DDeviceContextState *previous = nullptr;
    D3D_FEATURE_LEVEL selected{};
    D3D_FEATURE_LEVEL requested[] = {
        D3D_FEATURE_LEVEL_11_1,
        D3D_FEATURE_LEVEL_11_0,
    };

    HRESULT result = D3D11CreateDevice(
        nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr,
        D3D11_CREATE_DEVICE_BGRA_SUPPORT,
        requested, ARRAYSIZE(requested), D3D11_SDK_VERSION,
        &device, &selected, &context);
    if (!report("D3D11CreateDevice", result)) return 10;

    result = device->QueryInterface(IID_PPV_ARGS(&device1));
    if (!report("ID3D11Device::QueryInterface(ID3D11Device1)", result)) return 11;
    result = context->QueryInterface(IID_PPV_ARGS(&context1));
    if (!report("ID3D11DeviceContext::QueryInterface(ID3D11DeviceContext1)", result)) return 12;

    result = device1->CreateDeviceContextState(
        0, requested, ARRAYSIZE(requested), D3D11_SDK_VERSION,
        __uuidof(ID3D11Device1), &selected, &state);
    if (!report("ID3D11Device1::CreateDeviceContextState", result)) return 13;

    context1->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
    context1->SwapDeviceContextState(state, &previous);
    if (previous == nullptr) {
        std::printf("SwapDeviceContextState(new, previous): null previous state\n");
        return 14;
    }

    D3D11_PRIMITIVE_TOPOLOGY topology = D3D11_PRIMITIVE_TOPOLOGY_UNDEFINED;
    context1->IAGetPrimitiveTopology(&topology);
    std::printf("topology after new state: %u\n", static_cast<unsigned>(topology));
    if (topology != D3D11_PRIMITIVE_TOPOLOGY_UNDEFINED) return 15;

    context1->SwapDeviceContextState(previous, nullptr);
    context1->IAGetPrimitiveTopology(&topology);
    std::printf("topology after restore: %u\n", static_cast<unsigned>(topology));
    bool passed = topology == D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST;

    ID3DDeviceContextState *null_previous = reinterpret_cast<ID3DDeviceContextState *>(0xdeadbeef);
    context1->SwapDeviceContextState(nullptr, &null_previous);
    if (null_previous != nullptr) {
        std::printf("SwapDeviceContextState(null): previous output was not null\n");
        passed = false;
    }

    release(previous);
    release(state);
    release(context1);
    release(context);
    release(device1);
    release(device);
    return passed ? 0 : 20;
}
