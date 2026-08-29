#define UNICODE
#define _UNICODE
#define INITGUID
#include <windows.h>
#include <oleacc.h>
#include <cstdio>
#include <cstring>
#include <cwchar>

static HWND main_window;
static BOOL find_blank_window;
static const wchar_t *title_fragment;

static BOOL CALLBACK find_main_window(HWND window, LPARAM unused) {
    (void)unused;
    wchar_t title[512] = {0};
    wchar_t class_name[512] = {0};
    GetWindowTextW(window, title, 512);
    GetClassNameW(window, class_name, 512);
    if ((find_blank_window && IsWindowVisible(window) && !title[0]
            && std::wcsstr(class_name, L"HwndWrapper[YukkuriMovieMaker;"))
            || (!find_blank_window && std::wcsstr(title, title_fragment))) {
        main_window = window;
        return FALSE;
    }
    return TRUE;
}

static void print_utf8(BSTR value) {
    if (!value) return;
    int size = WideCharToMultiByte(CP_UTF8, 0, value, -1, nullptr, 0, nullptr, nullptr);
    if (size <= 1) return;
    char *buffer = static_cast<char *>(HeapAlloc(GetProcessHeap(), 0, size));
    if (!buffer) return;
    WideCharToMultiByte(CP_UTF8, 0, value, -1, buffer, size, nullptr, nullptr);
    std::fputs(buffer, stdout);
    HeapFree(GetProcessHeap(), 0, buffer);
}

static void describe(IAccessible *accessible, VARIANT child, int depth) {
    BSTR name = nullptr;
    VARIANT role{};
    VARIANT state{};
    VariantInit(&role);
    VariantInit(&state);
    LONG left = 0, top = 0, width = 0, height = 0;
    accessible->get_accName(child, &name);
    accessible->get_accRole(child, &role);
    accessible->get_accState(child, &state);
    accessible->accLocation(&left, &top, &width, &height, child);
    for (int index = 0; index < depth; ++index) std::fputs("  ", stdout);
    std::printf("id=%ld role=%ld state=0x%lx rect=%ld,%ld,%ld,%ld name=",
                child.vt == VT_I4 ? child.lVal : -1L,
                role.vt == VT_I4 ? role.lVal : -1L,
                state.vt == VT_I4 ? state.lVal : 0L,
                left, top, width, height);
    print_utf8(name);
    std::fputc('\n', stdout);
    SysFreeString(name);
    VariantClear(&role);
    VariantClear(&state);
}

static void walk(IAccessible *accessible, int depth) {
    VARIANT self{};
    self.vt = VT_I4;
    self.lVal = CHILDID_SELF;
    describe(accessible, self, depth);
    if (depth >= 8) return;

    LONG count = 0;
    if (FAILED(accessible->get_accChildCount(&count)) || count <= 0 || count > 4096) return;
    for (LONG index = 1; index <= count; ++index) {
        VARIANT child{};
        child.vt = VT_I4;
        child.lVal = index;
        IDispatch *dispatch = nullptr;
        HRESULT result = accessible->get_accChild(child, &dispatch);
        if (SUCCEEDED(result) && dispatch) {
            IAccessible *nested = nullptr;
            if (SUCCEEDED(dispatch->QueryInterface(IID_IAccessible,
                                                  reinterpret_cast<void **>(&nested)))) {
                walk(nested, depth + 1);
                nested->Release();
            } else {
                describe(accessible, child, depth + 1);
            }
            dispatch->Release();
        } else {
            describe(accessible, child, depth + 1);
        }
    }
}

int main(int argc, char **argv) {
    SetConsoleOutputCP(CP_UTF8);
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    find_blank_window = argc == 2 && std::strcmp(argv[1], "blank") == 0;
    wchar_t converted_title[512] = L"v4.55.1.1 Lite";
    if (argc == 3 && std::strcmp(argv[1], "title") == 0) {
        MultiByteToWideChar(CP_UTF8, 0, argv[2], -1, converted_title, 512);
    }
    title_fragment = converted_title;
    EnumWindows(find_main_window, 0);
    if (!main_window) return 2;
    IAccessible *accessible = nullptr;
    HRESULT result = AccessibleObjectFromWindow(
        main_window, OBJID_CLIENT, IID_IAccessible, reinterpret_cast<void **>(&accessible));
    std::printf("AccessibleObjectFromWindow: 0x%08lx\n", static_cast<unsigned long>(result));
    if (FAILED(result)) return 3;
    walk(accessible, 0);
    accessible->Release();
    CoUninitialize();
    return 0;
}
