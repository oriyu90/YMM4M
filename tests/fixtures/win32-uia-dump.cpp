#define UNICODE
#define _UNICODE
#include <windows.h>
#include <initguid.h>
#include <uiautomationclient.h>
#include <oleauto.h>
#include <cstdio>
#include <cstring>
#include <cwchar>

static void print_utf8(BSTR value) {
    if (!value || !*value) return;
    int size = WideCharToMultiByte(CP_UTF8, 0, value, -1, nullptr, 0, nullptr, nullptr);
    char *buffer = static_cast<char *>(HeapAlloc(GetProcessHeap(), 0, static_cast<SIZE_T>(size)));
    if (!buffer) return;
    WideCharToMultiByte(CP_UTF8, 0, value, -1, buffer, size, nullptr, nullptr);
    std::fputs(buffer, stdout);
    HeapFree(GetProcessHeap(), 0, buffer);
}

static void dump_element(IUIAutomationElement *element, IUIAutomationTreeWalker *walker, int depth) {
    BSTR name = nullptr, automation_id = nullptr, class_name = nullptr;
    CONTROLTYPEID control_type = 0;
    element->get_CurrentName(&name);
    element->get_CurrentAutomationId(&automation_id);
    element->get_CurrentClassName(&class_name);
    element->get_CurrentControlType(&control_type);
    for (int index = 0; index < depth; ++index) std::fputs("  ", stdout);
    std::printf("type=%d name=", static_cast<int>(control_type));
    print_utf8(name);
    std::fputs(" automationId=", stdout);
    print_utf8(automation_id);
    std::fputs(" class=", stdout);
    print_utf8(class_name);

    IUIAutomationValuePattern *value_pattern = nullptr;
    if (SUCCEEDED(element->GetCurrentPatternAs(UIA_ValuePatternId, IID_PPV_ARGS(&value_pattern))) && value_pattern) {
        BSTR value = nullptr;
        if (SUCCEEDED(value_pattern->get_CurrentValue(&value))) {
            std::fputs(" value=", stdout);
            print_utf8(value);
            SysFreeString(value);
        }
        value_pattern->Release();
    }
    std::fputc('\n', stdout);
    SysFreeString(name);
    SysFreeString(automation_id);
    SysFreeString(class_name);

    IUIAutomationElement *child = nullptr;
    if (FAILED(walker->GetFirstChildElement(element, &child))) return;
    while (child) {
        dump_element(child, walker, depth + 1);
        IUIAutomationElement *next = nullptr;
        walker->GetNextSiblingElement(child, &next);
        child->Release();
        child = next;
    }
}

struct window_search {
    HWND result;
    const wchar_t *target;
};

static BOOL CALLBACK find_window(HWND window, LPARAM parameter) {
    window_search *search = reinterpret_cast<window_search *>(parameter);
    wchar_t title[512] = {0};
    wchar_t class_name[512] = {0};
    GetWindowTextW(window, title, 512);
    GetClassNameW(window, class_name, 512);
    if ((std::wcscmp(search->target, L"") == 0 && IsWindowVisible(window)
            && !title[0] && std::wcsstr(class_name, L"HwndWrapper[YukkuriMovieMaker;"))
            || (std::wcscmp(search->target, L"An exception occurred") == 0
            && std::wcscmp(title, search->target) == 0)
            || (std::wcscmp(search->target, L"v4.55.1.1 Lite") == 0
            && std::wcsstr(title, search->target))) {
        search->result = window;
        return FALSE;
    }
    return TRUE;
}

int main(int argc, char **argv) {
    SetConsoleOutputCP(CP_UTF8);
    HRESULT result = CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    if (FAILED(result)) {
        std::fprintf(stderr, "CoInitializeEx failed: 0x%08lx\n", static_cast<unsigned long>(result));
        return 2;
    }
    IUIAutomation *automation = nullptr;
    result = CoCreateInstance(CLSID_CUIAutomation, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&automation));
    if (FAILED(result) || !automation) {
        std::fprintf(stderr, "CoCreateInstance(CUIAutomation) failed: 0x%08lx\n",
                     static_cast<unsigned long>(result));
        CoUninitialize();
        return 3;
    }
    window_search search = {
        nullptr,
        argc == 2 && std::strcmp(argv[1], "exception") == 0
            ? L"An exception occurred"
            : argc == 2 && std::strcmp(argv[1], "blank") == 0
                ? L"" : L"v4.55.1.1 Lite"
    };
    EnumWindows(find_window, reinterpret_cast<LPARAM>(&search));
    HWND window = search.result;
    if (!window) {
        std::fprintf(stderr, "target window not found\n");
        automation->Release();
        CoUninitialize();
        return 4;
    }
    IUIAutomationElement *root = nullptr;
    IUIAutomationTreeWalker *walker = nullptr;
    result = automation->ElementFromHandle(window, &root);
    if (FAILED(result))
        std::fprintf(stderr, "ElementFromHandle failed: 0x%08lx\n", static_cast<unsigned long>(result));
    if (SUCCEEDED(result)) {
        result = automation->get_ControlViewWalker(&walker);
        if (result == E_NOTIMPL) result = automation->get_RawViewWalker(&walker);
    }
    if (FAILED(result))
        std::fprintf(stderr, "tree walker creation failed: 0x%08lx\n", static_cast<unsigned long>(result));
    if (SUCCEEDED(result) && root && walker) dump_element(root, walker, 0);
    if (walker) walker->Release();
    if (root) root->Release();
    automation->Release();
    CoUninitialize();
    return FAILED(result) ? 5 : 0;
}
