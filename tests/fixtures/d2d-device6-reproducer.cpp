#define INITGUID
#include <windows.h>
#include <d3d11.h>
#include <d2d1_3.h>
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
    ID2D1Device6 *d2d_device6 = nullptr;
    ID2D1DeviceContext6 *d2d_context6 = nullptr;

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

    result = d2d_device->QueryInterface(IID_ID2D1Device6, reinterpret_cast<void **>(&d2d_device6));
    if (!report("ID2D1Device::QueryInterface(ID2D1Device6)", result)) return 14;

    result = d2d_device6->CreateDeviceContext(D2D1_DEVICE_CONTEXT_OPTIONS_NONE, &d2d_context6);
    bool passed = report("ID2D1Device6::CreateDeviceContext", result);

    release(d2d_context6);
    release(d2d_device6);
    release(d2d_device);
    release(d2d_factory);
    release(dxgi_device);
    release(d3d_context);
    release(d3d_device);
    return passed ? 0 : 20;
}
