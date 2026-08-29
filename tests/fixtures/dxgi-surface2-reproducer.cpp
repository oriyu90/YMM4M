#define INITGUID
#include <windows.h>
#include <d3d11.h>
#include <dxgi1_2.h>
#include <cstdio>

template <typename T>
static void release(T *object) {
    if (object != nullptr) object->Release();
}

static bool report(const char *operation, HRESULT result) {
    std::printf("%s: 0x%08lx\n", operation, static_cast<unsigned long>(result));
    return SUCCEEDED(result);
}

static LRESULT CALLBACK window_proc(HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
    return DefWindowProcW(window, message, wparam, lparam);
}

static bool test_swap_chain(IDXGIFactory2 *factory, ID3D11Device *device,
                            HWND window, UINT width, UINT height, const char *scope) {
    IDXGISwapChain1 *swap_chain = nullptr;
    IDXGISurface2 *surface = nullptr;
    DXGI_SWAP_CHAIN_DESC1 description{};
    description.Width = width;
    description.Height = height;
    description.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
    description.SampleDesc.Count = 1;
    description.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    description.BufferCount = 2;
    description.Scaling = DXGI_SCALING_STRETCH;
    description.SwapEffect = DXGI_SWAP_EFFECT_FLIP_SEQUENTIAL;
    description.AlphaMode = DXGI_ALPHA_MODE_IGNORE;

    HRESULT result = factory->CreateSwapChainForHwnd(
        device, window, &description, nullptr, nullptr, &swap_chain);
    std::printf("%s ", scope);
    if (!report("CreateSwapChainForHwnd", result)) return false;

    result = swap_chain->GetBuffer(0, IID_IDXGISurface2, reinterpret_cast<void **>(&surface));
    std::printf("%s ", scope);
    bool passed = report("GetBuffer(IDXGISurface2)", result);
    release(surface);
    release(swap_chain);
    return passed;
}

int main() {
    HINSTANCE instance = GetModuleHandleW(nullptr);
    WNDCLASSW window_class{};
    window_class.lpfnWndProc = window_proc;
    window_class.hInstance = instance;
    window_class.lpszClassName = L"YMM4M-DXGI-Reproducer";
    if (!RegisterClassW(&window_class) && GetLastError() != ERROR_CLASS_ALREADY_EXISTS) return 9;
    HWND window = CreateWindowExW(0, window_class.lpszClassName, L"YMM4M DXGI Reproducer",
                                  WS_OVERLAPPEDWINDOW, 0, 0, 640, 360,
                                  nullptr, nullptr, instance, nullptr);
    if (window == nullptr) return 9;
    HWND child = CreateWindowExW(0, window_class.lpszClassName, L"YMM4M DXGI Child",
                                WS_CHILD | WS_VISIBLE, 10, 10, 320, 180,
                                window, nullptr, instance, nullptr);
    if (child == nullptr) return 9;
    ShowWindow(window, SW_SHOWNORMAL);
    UpdateWindow(window);

    ID3D11Device *d3d_device = nullptr;
    ID3D11DeviceContext *d3d_context = nullptr;
    IDXGIDevice *dxgi_device = nullptr;
    IDXGIAdapter *adapter = nullptr;
    IDXGIFactory2 *factory = nullptr;
    D3D_FEATURE_LEVEL selected{};
    D3D_FEATURE_LEVEL requested[] = {
        D3D_FEATURE_LEVEL_11_1,
        D3D_FEATURE_LEVEL_11_0,
        D3D_FEATURE_LEVEL_10_1,
        D3D_FEATURE_LEVEL_10_0,
    };

    HRESULT result = D3D11CreateDevice(
        nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, D3D11_CREATE_DEVICE_BGRA_SUPPORT,
        requested, ARRAYSIZE(requested), D3D11_SDK_VERSION,
        &d3d_device, &selected, &d3d_context);
    if (!report("D3D11CreateDevice", result)) return 10;

    result = d3d_device->QueryInterface(IID_IDXGIDevice, reinterpret_cast<void **>(&dxgi_device));
    if (!report("ID3D11Device::QueryInterface(IDXGIDevice)", result)) return 11;
    result = dxgi_device->GetAdapter(&adapter);
    if (!report("IDXGIDevice::GetAdapter", result)) return 12;
    result = adapter->GetParent(IID_IDXGIFactory2, reinterpret_cast<void **>(&factory));
    if (!report("IDXGIAdapter::GetParent(IDXGIFactory2)", result)) return 13;

    bool parent_passed = test_swap_chain(factory, d3d_device, window, 640, 360, "top-level");
    bool child_passed = test_swap_chain(factory, d3d_device, child, 320, 180, "child");

    release(factory);
    release(adapter);
    release(dxgi_device);
    release(d3d_context);
    release(d3d_device);
    DestroyWindow(window);
    return parent_passed && child_passed ? 0 : 20;
}
