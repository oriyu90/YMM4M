#define INITGUID
#include <windows.h>
#include <d3d11.h>
#include <d2d1_1.h>
#include <d2d1effects.h>
#include <dxgi.h>
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
    ID3D11Device *d3d_device = nullptr;
    ID3D11DeviceContext *d3d_context = nullptr;
    IDXGIDevice *dxgi_device = nullptr;
    ID2D1Factory1 *d2d_factory = nullptr;
    ID2D1Device *d2d_device = nullptr;
    ID2D1DeviceContext *d2d_context = nullptr;
    ID2D1Effect *effect = nullptr;
    ID2D1Image *input = reinterpret_cast<ID2D1Image *>(0xdeadbeef);

    D3D_FEATURE_LEVEL requested[] = {
        D3D_FEATURE_LEVEL_11_1,
        D3D_FEATURE_LEVEL_11_0,
        D3D_FEATURE_LEVEL_10_1,
        D3D_FEATURE_LEVEL_10_0,
    };
    D3D_FEATURE_LEVEL selected{};
    HRESULT result = D3D11CreateDevice(
        nullptr,
        D3D_DRIVER_TYPE_HARDWARE,
        nullptr,
        D3D11_CREATE_DEVICE_BGRA_SUPPORT,
        requested,
        ARRAYSIZE(requested),
        D3D11_SDK_VERSION,
        &d3d_device,
        &selected,
        &d3d_context);
    if (!report("D3D11CreateDevice", result)) return 10;

    result = d3d_device->QueryInterface(IID_IDXGIDevice, reinterpret_cast<void **>(&dxgi_device));
    if (!report("ID3D11Device::QueryInterface(IDXGIDevice)", result)) return 11;

    D2D1_FACTORY_OPTIONS options{};
    result = D2D1CreateFactory(
        D2D1_FACTORY_TYPE_SINGLE_THREADED,
        IID_ID2D1Factory1,
        &options,
        reinterpret_cast<void **>(&d2d_factory));
    if (!report("D2D1CreateFactory(ID2D1Factory1)", result)) return 12;

    result = d2d_factory->CreateDevice(dxgi_device, &d2d_device);
    if (!report("ID2D1Factory1::CreateDevice", result)) return 13;

    result = d2d_device->CreateDeviceContext(D2D1_DEVICE_CONTEXT_OPTIONS_NONE, &d2d_context);
    if (!report("ID2D1Device::CreateDeviceContext", result)) return 14;

    result = d2d_context->CreateEffect(CLSID_D2D1GaussianBlur, &effect);
    if (!report("ID2D1DeviceContext::CreateEffect(GaussianBlur)", result)) return 15;

    effect->SetInput(0, nullptr, FALSE);
    effect->GetInput(0, &input);
    bool passed = input == nullptr;
    std::printf("ID2D1Effect::SetInput(NULL): %s\n", passed ? "passed" : "failed");
    release(input);
    release(effect);
    release(d2d_context);
    release(d2d_device);
    release(d2d_factory);
    release(dxgi_device);
    release(d3d_context);
    release(d3d_device);
    return passed ? 0 : 20;
}
