#define INITGUID
#include <windows.h>
#include <d3d11.h>
#include <d2d1_1.h>
#include <d2d1effects.h>
#include <dxgi.h>
#include <cstdio>
#include <cstring>

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
    ID2D1Effect *premultiply_effect = nullptr;
    ID2D1Bitmap1 *bitmap = nullptr;
    ID2D1Image *output = nullptr;
    ID2D1CommandList *command_list = nullptr;
    ID2D1SolidColorBrush *brush = nullptr;
    ID2D1Bitmap1 *target = nullptr;
    ID2D1Bitmap1 *readback = nullptr;
    ID2D1CommandList *image_brush_source = nullptr;
    ID2D1CommandList *image_brush_commands = nullptr;
    ID2D1ImageBrush *image_brush = nullptr;
    ID2D1SolidColorBrush *blue_brush = nullptr;
    ID2D1Bitmap1 *image_brush_target = nullptr;
    ID2D1Bitmap1 *image_brush_readback = nullptr;
    ID2D1CommandList *nested_commands = nullptr;
    ID2D1CommandList *transparent_clear_commands = nullptr;

    D3D_FEATURE_LEVEL requested[] = {
        D3D_FEATURE_LEVEL_11_1,
        D3D_FEATURE_LEVEL_11_0,
        D3D_FEATURE_LEVEL_10_1,
        D3D_FEATURE_LEVEL_10_0,
    };
    D3D_FEATURE_LEVEL selected{};
    HRESULT result = D3D11CreateDevice(
        nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr,
        D3D11_CREATE_DEVICE_BGRA_SUPPORT, requested, ARRAYSIZE(requested),
        D3D11_SDK_VERSION, &d3d_device, &selected, &d3d_context);
    if (!report("D3D11CreateDevice", result)) return 10;

    result = d3d_device->QueryInterface(IID_IDXGIDevice, reinterpret_cast<void **>(&dxgi_device));
    if (!report("ID3D11Device::QueryInterface(IDXGIDevice)", result)) return 11;

    D2D1_FACTORY_OPTIONS options{};
    result = D2D1CreateFactory(D2D1_FACTORY_TYPE_SINGLE_THREADED,
        IID_ID2D1Factory1, &options, reinterpret_cast<void **>(&d2d_factory));
    if (!report("D2D1CreateFactory(ID2D1Factory1)", result)) return 12;

    result = d2d_factory->CreateDevice(dxgi_device, &d2d_device);
    if (!report("ID2D1Factory1::CreateDevice", result)) return 13;

    result = d2d_device->CreateDeviceContext(D2D1_DEVICE_CONTEXT_OPTIONS_NONE, &d2d_context);
    if (!report("ID2D1Device::CreateDeviceContext", result)) return 14;

    result = d2d_context->CreateEffect(CLSID_D2D13DTransform, &effect);
    if (!report("ID2D1DeviceContext::CreateEffect(3DTransform)", result)) return 15;

    result = d2d_context->CreateEffect(CLSID_D2D1Premultiply, &premultiply_effect);
    if (!report("ID2D1DeviceContext::CreateEffect(Premultiply)", result)) return 21;

    UINT32 interpolation = 0;
    result = effect->GetValue(0, D2D1_PROPERTY_TYPE_ENUM,
        reinterpret_cast<BYTE *>(&interpolation), sizeof(interpolation));
    if (!report("GetValue(InterpolationMode)", result) || interpolation != 1) return 16;

    UINT32 border = ~0u;
    result = effect->GetValue(1, D2D1_PROPERTY_TYPE_ENUM,
        reinterpret_cast<BYTE *>(&border), sizeof(border));
    if (!report("GetValue(BorderMode)", result) || border != 0) return 17;

    D2D1_MATRIX_4X4_F identity{};
    result = effect->GetValue(2, D2D1_PROPERTY_TYPE_MATRIX_4X4,
        reinterpret_cast<BYTE *>(&identity), sizeof(identity));
    if (!report("GetValue(TransformMatrix)", result)) return 18;
    bool identity_ok = identity._11 == 1.0f && identity._22 == 1.0f
        && identity._33 == 1.0f && identity._44 == 1.0f;

    D2D1_MATRIX_4X4_F changed = identity;
    changed._41 = 12.0f;
    result = effect->SetValue(2, D2D1_PROPERTY_TYPE_MATRIX_4X4,
        reinterpret_cast<const BYTE *>(&changed), sizeof(changed));
    if (!report("SetValue(TransformMatrix)", result)) return 19;

    D2D1_MATRIX_4X4_F roundtrip{};
    result = effect->GetValue(2, D2D1_PROPERTY_TYPE_MATRIX_4X4,
        reinterpret_cast<BYTE *>(&roundtrip), sizeof(roundtrip));
    bool passed = report("GetValue(TransformMatrix roundtrip)", result)
        && identity_ok && std::memcmp(&changed, &roundtrip, sizeof(changed)) == 0;

    D2D1_BITMAP_PROPERTIES1 bitmap_properties{};
    bitmap_properties.pixelFormat.format = DXGI_FORMAT_B8G8R8A8_UNORM;
    bitmap_properties.pixelFormat.alphaMode = D2D1_ALPHA_MODE_PREMULTIPLIED;
    bitmap_properties.dpiX = 96.0f;
    bitmap_properties.dpiY = 96.0f;
    result = d2d_context->CreateBitmap(D2D1_SIZE_U{16, 8}, nullptr, 0,
        &bitmap_properties, &bitmap);
    passed = report("ID2D1DeviceContext::CreateBitmap", result) && passed;
    if (SUCCEEDED(result)) {
        premultiply_effect->SetInput(0, bitmap, FALSE);
        ID2D1Image *premultiply_output = nullptr;
        premultiply_effect->GetOutput(&premultiply_output);
        D2D1_RECT_F premultiply_bounds{};
        result = d2d_context->GetImageLocalBounds(premultiply_output, &premultiply_bounds);
        passed = report("GetImageLocalBounds(Premultiply output)", result)
            && premultiply_bounds.left == 0.0f && premultiply_bounds.top == 0.0f
            && premultiply_bounds.right == 16.0f && premultiply_bounds.bottom == 8.0f && passed;
        release(premultiply_output);

        effect->SetInput(0, bitmap, FALSE);
        effect->GetOutput(&output);
        D2D1_RECT_F bounds{};
        result = d2d_context->GetImageLocalBounds(output, &bounds);
        passed = report("GetImageLocalBounds(3DTransform output)", result)
            && bounds.left == 0.0f && bounds.top == 0.0f
            && bounds.right == 16.0f && bounds.bottom == 8.0f && passed;
    }

    result = d2d_context->CreateCommandList(&command_list);
    passed = report("ID2D1DeviceContext::CreateCommandList", result) && passed;
    D2D1_COLOR_F white{1.0f, 1.0f, 1.0f, 1.0f};
    result = d2d_context->CreateSolidColorBrush(white, &brush);
    passed = report("ID2D1DeviceContext::CreateSolidColorBrush", result) && passed;
    if (command_list && brush) {
        d2d_context->SetTarget(command_list);
        d2d_context->BeginDraw();
        D2D1_RECT_F drawn_rect{4.0f, 5.0f, 20.0f, 15.0f};
        d2d_context->FillRectangle(drawn_rect, brush);
        result = d2d_context->EndDraw();
        passed = report("ID2D1DeviceContext::EndDraw(command list)", result) && passed;
        d2d_context->SetTarget(nullptr);
        result = command_list->Close();
        passed = report("ID2D1CommandList::Close", result) && passed;

        result = d2d_context->CreateCommandList(&nested_commands);
        passed = report("CreateCommandList(nested image)", result) && passed;
        if (SUCCEEDED(result)) {
            d2d_context->SetTarget(nested_commands);
            d2d_context->BeginDraw();
            d2d_context->DrawImage(command_list);
            result = d2d_context->EndDraw();
            passed = report("EndDraw(nested image)", result) && passed;
            d2d_context->SetTarget(nullptr);
            result = nested_commands->Close();
            passed = report("Close(nested image)", result) && passed;
            D2D1_RECT_F nested_bounds{};
            result = d2d_context->GetImageLocalBounds(nested_commands, &nested_bounds);
            passed = report("GetImageLocalBounds(nested image)", result)
                && nested_bounds.left == 4.0f && nested_bounds.top == 5.0f
                && nested_bounds.right == 20.0f && nested_bounds.bottom == 15.0f && passed;
        }
        effect->SetInput(0, command_list, FALSE);
        release(output);
        output = nullptr;
        effect->GetOutput(&output);
        D2D1_RECT_F bounds{};
        result = d2d_context->GetImageLocalBounds(output, &bounds);
        passed = report("GetImageLocalBounds(command-list effect)", result)
            && bounds.left == 4.0f && bounds.top == 5.0f
            && bounds.right == 20.0f && bounds.bottom == 15.0f && passed;

        effect->SetValue(2, D2D1_PROPERTY_TYPE_MATRIX_4X4,
            reinterpret_cast<const BYTE *>(&identity), sizeof(identity));
        bitmap_properties.bitmapOptions = D2D1_BITMAP_OPTIONS_TARGET;
        result = d2d_context->CreateBitmap(D2D1_SIZE_U{32, 24}, nullptr, 0,
            &bitmap_properties, &target);
        passed = report("CreateBitmap(effect render target)", result) && passed;
        if (SUCCEEDED(result)) {
            d2d_context->SetTarget(target);
            d2d_context->BeginDraw();
            d2d_context->Clear(D2D1_COLOR_F{0.0f, 0.0f, 0.0f, 0.0f});
            d2d_context->DrawImage(output);
            result = d2d_context->EndDraw();
            passed = report("EndDraw(command-list effect output)", result) && passed;
            d2d_context->SetTarget(nullptr);

            bitmap_properties.bitmapOptions = static_cast<D2D1_BITMAP_OPTIONS>(
                D2D1_BITMAP_OPTIONS_CPU_READ | D2D1_BITMAP_OPTIONS_CANNOT_DRAW);
            result = d2d_context->CreateBitmap(D2D1_SIZE_U{32, 24}, nullptr, 0,
                &bitmap_properties, &readback);
            passed = report("CreateBitmap(effect readback)", result) && passed;
            if (SUCCEEDED(result)) {
                result = readback->CopyFromBitmap(nullptr, target, nullptr);
                passed = report("CopyFromBitmap(effect output)", result) && passed;
                D2D1_MAPPED_RECT mapped{};
                result = readback->Map(D2D1_MAP_OPTIONS_READ, &mapped);
                bool pixel_ok = false;
                if (SUCCEEDED(result)) {
                    const BYTE *pixel = mapped.bits + 8 * mapped.pitch + 8 * 4;
                    pixel_ok = pixel[0] > 240 && pixel[1] > 240
                        && pixel[2] > 240 && pixel[3] > 240;
                    std::printf("effect pixel BGRA: %u %u %u %u\n",
                        pixel[0], pixel[1], pixel[2], pixel[3]);
                    readback->Unmap();
                }
                passed = report("Map(effect output)", result) && pixel_ok && passed;
            }

            d2d_context->SetTarget(target);
            d2d_context->BeginDraw();
            d2d_context->Clear(D2D1_COLOR_F{0.0f, 0.0f, 0.0f, 0.0f});
            d2d_context->DrawImage(command_list, D2D1_POINT_2F{1.0f, 1.0f});
            result = d2d_context->EndDraw();
            passed = report("EndDraw(command-list target offset)", result) && passed;
            d2d_context->SetTarget(nullptr);
            if (readback) {
                result = readback->CopyFromBitmap(nullptr, target, nullptr);
                passed = report("CopyFromBitmap(command-list target offset)", result) && passed;
                D2D1_MAPPED_RECT mapped{};
                result = readback->Map(D2D1_MAP_OPTIONS_READ, &mapped);
                bool pixel_ok = false;
                if (SUCCEEDED(result)) {
                    const BYTE *pixel = mapped.bits + 7 * mapped.pitch + 6 * 4;
                    pixel_ok = pixel[0] > 240 && pixel[1] > 240
                        && pixel[2] > 240 && pixel[3] > 240;
                    std::printf("target-offset pixel BGRA: %u %u %u %u\n",
                        pixel[0], pixel[1], pixel[2], pixel[3]);
                    readback->Unmap();
                }
                passed = report("Map(command-list target offset)", result) && pixel_ok && passed;
            }

            result = d2d_context->CreateCommandList(&transparent_clear_commands);
            passed = report("CreateCommandList(transparent clear)", result) && passed;
            if (SUCCEEDED(result)) {
                d2d_context->SetTarget(transparent_clear_commands);
                d2d_context->BeginDraw();
                d2d_context->Clear(D2D1_COLOR_F{0.0f, 0.0f, 0.0f, 0.0f});
                result = d2d_context->EndDraw();
                passed = report("EndDraw(transparent clear)", result) && passed;
                d2d_context->SetTarget(nullptr);
                result = transparent_clear_commands->Close();
                passed = report("Close(transparent clear)", result) && passed;

                d2d_context->SetTarget(target);
                d2d_context->BeginDraw();
                d2d_context->Clear(D2D1_COLOR_F{0.0f, 1.0f, 0.0f, 1.0f});
                d2d_context->DrawImage(transparent_clear_commands);
                result = d2d_context->EndDraw();
                passed = report("EndDraw(transparent clear over green)", result) && passed;
                d2d_context->SetTarget(nullptr);
                if (readback) {
                    result = readback->CopyFromBitmap(nullptr, target, nullptr);
                    passed = report("CopyFromBitmap(transparent clear)", result) && passed;
                    D2D1_MAPPED_RECT mapped{};
                    result = readback->Map(D2D1_MAP_OPTIONS_READ, &mapped);
                    bool pixel_ok = false;
                    if (SUCCEEDED(result)) {
                        const BYTE *pixel = mapped.bits + 2 * mapped.pitch + 2 * 4;
                        pixel_ok = pixel[0] < 16 && pixel[1] > 240
                            && pixel[2] < 16 && pixel[3] > 240;
                        readback->Unmap();
                    }
                    passed = report("Map(transparent clear)", result) && pixel_ok && passed;
                }
            }
        }
    }

    result = d2d_context->CreateCommandList(&image_brush_source);
    passed = report("CreateCommandList(image-brush source)", result) && passed;
    D2D1_COLOR_F blue{0.0f, 0.0f, 1.0f, 1.0f};
    result = d2d_context->CreateSolidColorBrush(blue, &blue_brush);
    passed = report("CreateSolidColorBrush(image-brush source)", result) && passed;
    if (image_brush_source && blue_brush) {
        d2d_context->SetTarget(image_brush_source);
        d2d_context->BeginDraw();
        d2d_context->FillRectangle(D2D1_RECT_F{0.0f, 0.0f, 16.0f, 16.0f}, blue_brush);
        result = d2d_context->EndDraw();
        passed = report("EndDraw(image-brush source)", result) && passed;
        d2d_context->SetTarget(nullptr);
        result = image_brush_source->Close();
        passed = report("Close(image-brush source)", result) && passed;

        D2D1_IMAGE_BRUSH_PROPERTIES image_properties{};
        image_properties.sourceRectangle = D2D1_RECT_F{0.0f, 0.0f, 16.0f, 16.0f};
        image_properties.extendModeX = D2D1_EXTEND_MODE_CLAMP;
        image_properties.extendModeY = D2D1_EXTEND_MODE_CLAMP;
        image_properties.interpolationMode = D2D1_INTERPOLATION_MODE_LINEAR;
        D2D1_BRUSH_PROPERTIES brush_properties{};
        brush_properties.opacity = 1.0f;
        brush_properties.transform = D2D1_MATRIX_3X2_F{{{
            1.0f, 0.0f, 0.0f, 1.0f, 4.0f, 4.0f,
        }}};
        result = d2d_context->CreateImageBrush(image_brush_source, image_properties,
            brush_properties, &image_brush);
        passed = report("CreateImageBrush(command-list source)", result) && passed;
    }
    result = d2d_context->CreateCommandList(&image_brush_commands);
    passed = report("CreateCommandList(image-brush fill)", result) && passed;
    if (image_brush_commands && image_brush) {
        d2d_context->SetTarget(image_brush_commands);
        d2d_context->BeginDraw();
        d2d_context->FillRectangle(D2D1_RECT_F{4.0f, 4.0f, 20.0f, 20.0f}, image_brush);
        result = d2d_context->EndDraw();
        passed = report("EndDraw(image-brush fill)", result) && passed;
        d2d_context->SetTarget(nullptr);
        result = image_brush_commands->Close();
        passed = report("Close(image-brush fill)", result) && passed;

        bitmap_properties.bitmapOptions = D2D1_BITMAP_OPTIONS_TARGET;
        result = d2d_context->CreateBitmap(D2D1_SIZE_U{24, 24}, nullptr, 0,
            &bitmap_properties, &image_brush_target);
        passed = report("CreateBitmap(image-brush target)", result) && passed;
        if (SUCCEEDED(result)) {
            d2d_context->SetTarget(image_brush_target);
            d2d_context->BeginDraw();
            d2d_context->Clear(D2D1_COLOR_F{0.0f, 0.0f, 0.0f, 0.0f});
            d2d_context->DrawImage(image_brush_commands);
            result = d2d_context->EndDraw();
            passed = report("EndDraw(image-brush output)", result) && passed;
            d2d_context->SetTarget(nullptr);

            bitmap_properties.bitmapOptions = static_cast<D2D1_BITMAP_OPTIONS>(
                D2D1_BITMAP_OPTIONS_CPU_READ | D2D1_BITMAP_OPTIONS_CANNOT_DRAW);
            result = d2d_context->CreateBitmap(D2D1_SIZE_U{24, 24}, nullptr, 0,
                &bitmap_properties, &image_brush_readback);
            passed = report("CreateBitmap(image-brush readback)", result) && passed;
            if (SUCCEEDED(result)) {
                result = image_brush_readback->CopyFromBitmap(nullptr, image_brush_target, nullptr);
                passed = report("CopyFromBitmap(image-brush output)", result) && passed;
                D2D1_MAPPED_RECT mapped{};
                result = image_brush_readback->Map(D2D1_MAP_OPTIONS_READ, &mapped);
                bool pixel_ok = false;
                if (SUCCEEDED(result)) {
                    const BYTE *pixel = mapped.bits + 8 * mapped.pitch + 8 * 4;
                    pixel_ok = pixel[0] > 240 && pixel[1] < 16
                        && pixel[2] < 16 && pixel[3] > 240;
                    std::printf("image-brush pixel BGRA: %u %u %u %u\n",
                        pixel[0], pixel[1], pixel[2], pixel[3]);
                    image_brush_readback->Unmap();
                }
                passed = report("Map(image-brush output)", result) && pixel_ok && passed;
            }
        }
    }
    std::printf("3D transform contract: %s\n", passed ? "passed" : "failed");

    release(image_brush_readback);
    release(image_brush_target);
    release(image_brush);
    release(image_brush_commands);
    release(blue_brush);
    release(image_brush_source);
    release(nested_commands);
    release(transparent_clear_commands);
    release(brush);
    release(readback);
    release(target);
    release(command_list);
    release(output);
    release(bitmap);
    release(premultiply_effect);
    release(effect);
    release(d2d_context);
    release(d2d_device);
    release(d2d_factory);
    release(dxgi_device);
    release(d3d_context);
    release(d3d_device);
    return passed ? 0 : 20;
}
