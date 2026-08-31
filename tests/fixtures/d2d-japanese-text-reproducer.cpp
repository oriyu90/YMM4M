#define INITGUID
#include <windows.h>
#include <d3d11.h>
#include <d2d1_1.h>
#include <dwrite.h>
#include <dxgi.h>
#include <cstdio>

template <typename T>
static void release(T *object) {
    if (object) object->Release();
}

static bool report(const char *operation, HRESULT result) {
    std::printf("%s: 0x%08lx\n", operation, static_cast<unsigned long>(result));
    return SUCCEEDED(result);
}

static bool write_bmp(const wchar_t *path, const D2D1_MAPPED_RECT &mapped,
        UINT32 width, UINT32 height) {
    BITMAPFILEHEADER file_header{};
    BITMAPINFOHEADER info_header{};
    const DWORD row_size = width * 4;
    const DWORD pixel_size = row_size * height;
    file_header.bfType = 0x4d42;
    file_header.bfOffBits = sizeof(file_header) + sizeof(info_header);
    file_header.bfSize = file_header.bfOffBits + pixel_size;
    info_header.biSize = sizeof(info_header);
    info_header.biWidth = static_cast<LONG>(width);
    info_header.biHeight = -static_cast<LONG>(height);
    info_header.biPlanes = 1;
    info_header.biBitCount = 32;
    info_header.biCompression = BI_RGB;

    HANDLE file = CreateFileW(path, GENERIC_WRITE, 0, nullptr, CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL, nullptr);
    if (file == INVALID_HANDLE_VALUE) return false;
    DWORD written = 0;
    bool ok = WriteFile(file, &file_header, sizeof(file_header), &written, nullptr)
        && WriteFile(file, &info_header, sizeof(info_header), &written, nullptr);
    for (UINT32 y = 0; ok && y < height; ++y)
        ok = WriteFile(file, mapped.bits + y * mapped.pitch, row_size, &written, nullptr);
    CloseHandle(file);
    return ok;
}

int wmain(int argc, wchar_t **argv) {
    ID3D11Device *d3d_device = nullptr;
    ID3D11DeviceContext *d3d_context = nullptr;
    IDXGIDevice *dxgi_device = nullptr;
    ID2D1Factory1 *d2d_factory = nullptr;
    ID2D1Device *d2d_device = nullptr;
    ID2D1DeviceContext *d2d_context = nullptr;
    IDWriteFactory *dwrite_factory = nullptr;
    IDWriteTextFormat *format = nullptr;
    IDWriteTextLayout *layout = nullptr;
    ID2D1SolidColorBrush *brush = nullptr;
    ID2D1CommandList *commands = nullptr;
    ID2D1Bitmap1 *target = nullptr;
    ID2D1Bitmap1 *readback = nullptr;

    D3D_FEATURE_LEVEL selected{};
    HRESULT hr = D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr,
        D3D11_CREATE_DEVICE_BGRA_SUPPORT, nullptr, 0, D3D11_SDK_VERSION,
        &d3d_device, &selected, &d3d_context);
    if (!report("D3D11CreateDevice", hr)) return 10;
    hr = d3d_device->QueryInterface(IID_IDXGIDevice,
        reinterpret_cast<void **>(&dxgi_device));
    if (!report("QueryInterface(IDXGIDevice)", hr)) return 11;
    D2D1_FACTORY_OPTIONS options{};
    hr = D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED,
        IID_ID2D1Factory1, &options, reinterpret_cast<void **>(&d2d_factory));
    if (!report("D2D1CreateFactory", hr)) return 12;
    hr = d2d_factory->CreateDevice(dxgi_device, &d2d_device);
    if (!report("CreateDevice", hr)) return 13;
    hr = d2d_device->CreateDeviceContext(D2D1_DEVICE_CONTEXT_OPTIONS_NONE, &d2d_context);
    if (!report("CreateDeviceContext", hr)) return 14;
    hr = DWriteCreateFactory(DWRITE_FACTORY_TYPE_ISOLATED, IID_IDWriteFactory,
        reinterpret_cast<IUnknown **>(&dwrite_factory));
    if (!report("DWriteCreateFactory", hr)) return 15;
    hr = dwrite_factory->CreateTextFormat(L"Noto Sans CJK JP", nullptr,
        DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STYLE_NORMAL,
        DWRITE_FONT_STRETCH_NORMAL, 64.0f, L"ja-JP", &format);
    if (!report("CreateTextFormat", hr)) return 16;
    const wchar_t text[] = L"日本語テストABC123";
    hr = dwrite_factory->CreateTextLayout(text, ARRAYSIZE(text) - 1, format,
        640.0f, 200.0f, &layout);
    if (!report("CreateTextLayout", hr)) return 17;
    hr = d2d_context->CreateSolidColorBrush(D2D1_COLOR_F{1, 1, 1, 1}, &brush);
    if (!report("CreateSolidColorBrush", hr)) return 18;
    hr = d2d_context->CreateCommandList(&commands);
    if (!report("CreateCommandList", hr)) return 19;
    d2d_context->SetTarget(commands);
    d2d_context->BeginDraw();
    d2d_context->DrawTextLayout(D2D1_POINT_2F{10, 20}, layout, brush,
        D2D1_DRAW_TEXT_OPTIONS_NONE);
    hr = d2d_context->EndDraw();
    if (!report("EndDraw(command list)", hr)) return 20;
    d2d_context->SetTarget(nullptr);
    hr = commands->Close();
    if (!report("Close(command list)", hr)) return 21;

    D2D1_BITMAP_PROPERTIES1 props{};
    props.pixelFormat = D2D1_PIXEL_FORMAT{DXGI_FORMAT_B8G8R8A8_UNORM,
        D2D1_ALPHA_MODE_PREMULTIPLIED};
    props.dpiX = props.dpiY = 96.0f;
    props.bitmapOptions = D2D1_BITMAP_OPTIONS_TARGET;
    hr = d2d_context->CreateBitmap(D2D1_SIZE_U{640, 200}, nullptr, 0, &props, &target);
    if (!report("CreateBitmap(target)", hr)) return 22;
    d2d_context->SetTarget(target);
    d2d_context->BeginDraw();
    d2d_context->Clear(D2D1_COLOR_F{0, 0, 0, 1});
    d2d_context->DrawImage(commands);
    hr = d2d_context->EndDraw();
    if (!report("EndDraw(replay)", hr)) return 23;
    d2d_context->SetTarget(nullptr);

    props.bitmapOptions = static_cast<D2D1_BITMAP_OPTIONS>(
        D2D1_BITMAP_OPTIONS_CPU_READ | D2D1_BITMAP_OPTIONS_CANNOT_DRAW);
    hr = d2d_context->CreateBitmap(D2D1_SIZE_U{640, 200}, nullptr, 0, &props, &readback);
    if (!report("CreateBitmap(readback)", hr)) return 24;
    hr = readback->CopyFromBitmap(nullptr, target, nullptr);
    if (!report("CopyFromBitmap", hr)) return 25;
    D2D1_MAPPED_RECT mapped{};
    hr = readback->Map(D2D1_MAP_OPTIONS_READ, &mapped);
    if (!report("Map", hr)) return 26;
    const wchar_t *output_path = argc > 1 ? argv[1] : L"Z:\\private\\tmp\\d2d-japanese-text.bmp";
    bool written = write_bmp(output_path, mapped, 640, 200);
    readback->Unmap();
    std::printf("wrote=%d\n", written);

    release(readback);
    release(target);
    release(commands);
    release(brush);
    release(layout);
    release(format);
    release(dwrite_factory);
    release(d2d_context);
    release(d2d_device);
    release(d2d_factory);
    release(dxgi_device);
    release(d3d_context);
    release(d3d_device);
    return written ? 0 : 27;
}
