#define INITGUID
#include <windows.h>
#include <d3d11.h>
#include <d3dcompiler.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>

template <typename T>
static void release(T *object) {
    if (object != nullptr) object->Release();
}

static void print_shader_error(ID3DBlob *error) {
    if (error == nullptr) return;
    std::fwrite(error->GetBufferPointer(), 1, error->GetBufferSize(), stderr);
    std::fputc('\n', stderr);
}

static HRESULT run_iteration(unsigned int iteration) {
    static const char shader_source[] =
        "RWByteAddressBuffer output : register(u0);\n"
        "[numthreads(64, 1, 1)]\n"
        "void main(uint3 id : SV_DispatchThreadID) {\n"
        "    output.Store(id.x * 4, id.x ^ 0x5a5a5a5a);\n"
        "}\n";
    constexpr UINT value_count = 256;
    constexpr UINT byte_width = value_count * sizeof(UINT);

    ID3DBlob *shader_blob = nullptr;
    ID3DBlob *shader_error = nullptr;
    HRESULT result = D3DCompile(
        shader_source, std::strlen(shader_source), "compute-reproducer.hlsl",
        nullptr, nullptr, "main", "cs_5_0",
        D3DCOMPILE_ENABLE_STRICTNESS, 0, &shader_blob, &shader_error);
    if (FAILED(result)) {
        std::fprintf(stderr, "iteration %u D3DCompile: 0x%08lx\n",
            iteration, static_cast<unsigned long>(result));
        print_shader_error(shader_error);
        release(shader_error);
        return result;
    }
    release(shader_error);

    ID3D11Device *device = nullptr;
    ID3D11DeviceContext *context = nullptr;
    D3D_FEATURE_LEVEL selected{};
    const D3D_FEATURE_LEVEL requested[] = {
        D3D_FEATURE_LEVEL_11_0,
        D3D_FEATURE_LEVEL_10_1,
        D3D_FEATURE_LEVEL_10_0,
    };
    result = D3D11CreateDevice(
        nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, 0,
        requested, ARRAYSIZE(requested), D3D11_SDK_VERSION,
        &device, &selected, &context);
    if (FAILED(result)) {
        std::fprintf(stderr, "iteration %u D3D11CreateDevice: 0x%08lx\n",
            iteration, static_cast<unsigned long>(result));
        release(shader_blob);
        return result;
    }

    ID3D11ComputeShader *shader = nullptr;
    result = device->CreateComputeShader(
        shader_blob->GetBufferPointer(), shader_blob->GetBufferSize(), nullptr, &shader);
    release(shader_blob);
    if (FAILED(result)) {
        std::fprintf(stderr, "iteration %u CreateComputeShader: 0x%08lx\n",
            iteration, static_cast<unsigned long>(result));
        release(context);
        release(device);
        return result;
    }

    D3D11_BUFFER_DESC output_desc{};
    output_desc.ByteWidth = byte_width;
    output_desc.Usage = D3D11_USAGE_DEFAULT;
    output_desc.BindFlags = D3D11_BIND_UNORDERED_ACCESS;
    output_desc.MiscFlags = D3D11_RESOURCE_MISC_BUFFER_ALLOW_RAW_VIEWS;
    ID3D11Buffer *output = nullptr;
    result = device->CreateBuffer(&output_desc, nullptr, &output);

    D3D11_UNORDERED_ACCESS_VIEW_DESC view_desc{};
    view_desc.Format = DXGI_FORMAT_R32_TYPELESS;
    view_desc.ViewDimension = D3D11_UAV_DIMENSION_BUFFER;
    view_desc.Buffer.NumElements = value_count;
    view_desc.Buffer.Flags = D3D11_BUFFER_UAV_FLAG_RAW;
    ID3D11UnorderedAccessView *view = nullptr;
    if (SUCCEEDED(result)) result = device->CreateUnorderedAccessView(output, &view_desc, &view);

    D3D11_BUFFER_DESC staging_desc{};
    staging_desc.ByteWidth = byte_width;
    staging_desc.Usage = D3D11_USAGE_STAGING;
    staging_desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
    ID3D11Buffer *staging = nullptr;
    if (SUCCEEDED(result)) result = device->CreateBuffer(&staging_desc, nullptr, &staging);

    if (SUCCEEDED(result)) {
        context->CSSetShader(shader, nullptr, 0);
        context->CSSetUnorderedAccessViews(0, 1, &view, nullptr);
        context->Dispatch(value_count / 64, 1, 1);
        ID3D11UnorderedAccessView *null_view = nullptr;
        context->CSSetUnorderedAccessViews(0, 1, &null_view, nullptr);
        context->CopyResource(staging, output);

        D3D11_MAPPED_SUBRESOURCE mapped{};
        result = context->Map(staging, 0, D3D11_MAP_READ, 0, &mapped);
        if (SUCCEEDED(result)) {
            const auto *values = static_cast<const UINT *>(mapped.pData);
            for (UINT i = 0; i < value_count; ++i) {
                const UINT expected = i ^ 0x5a5a5a5a;
                if (values[i] != expected) {
                    std::fprintf(stderr,
                        "iteration %u value[%u]: expected 0x%08x, got 0x%08x\n",
                        iteration, i, expected, values[i]);
                    result = E_FAIL;
                    break;
                }
            }
            context->Unmap(staging, 0);
        }
    }

    if (FAILED(result)) {
        std::fprintf(stderr, "iteration %u compute/readback: 0x%08lx\n",
            iteration, static_cast<unsigned long>(result));
    }

    context->ClearState();
    context->Flush();
    release(staging);
    release(view);
    release(output);
    release(shader);
    release(context);
    release(device);
    return result;
}

int main(int argc, char **argv) {
    unsigned long iterations = 100;
    if (argc > 1) {
        char *end = nullptr;
        iterations = std::strtoul(argv[1], &end, 10);
        if (end == argv[1] || *end != '\0' || iterations == 0 || iterations > 100000) {
            std::fprintf(stderr, "usage: %s [iterations: 1..100000]\n", argv[0]);
            return 2;
        }
    }

    for (unsigned long i = 0; i < iterations; ++i) {
        HRESULT result = run_iteration(static_cast<unsigned int>(i + 1));
        if (FAILED(result)) return 10;
        if ((i + 1) % 10 == 0 || i + 1 == iterations) {
            std::printf("completed %lu/%lu\n", i + 1, iterations);
            std::fflush(stdout);
        }
    }
    return 0;
}
