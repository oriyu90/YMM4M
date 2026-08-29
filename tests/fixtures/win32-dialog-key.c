#define UNICODE
#define _UNICODE
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <wchar.h>

static HWND dialog_window;
static const wchar_t *title_fragment;

static BOOL CALLBACK find_dialog(HWND window, LPARAM unused) {
    (void)unused;
    wchar_t title[512] = {0};
    GetWindowTextW(window, title, 512);
    if (IsWindowVisible(window) && wcsstr(title, title_fragment)) {
        dialog_window = window;
        return FALSE;
    }
    return TRUE;
}

static void print_window(const char *label, HWND window) {
    wchar_t title[512] = {0};
    wchar_t class_name[512] = {0};
    GetWindowTextW(window, title, 512);
    GetClassNameW(window, class_name, 512);
    wprintf(L"%hs=%p title=%ls class=%ls\n", label, (void *)window, title, class_name);
}

int wmain(int argc, wchar_t **argv) {
    if (argc < 2 || argc > 3) return 1;
    title_fragment = argv[1];
    EnumWindows(find_dialog, 0);
    if (!dialog_window) return 2;

    DWORD thread = GetWindowThreadProcessId(dialog_window, NULL);
    GUITHREADINFO info = {.cbSize = sizeof(info)};
    if (!GetGUIThreadInfo(thread, &info)) return 3;
    print_window("dialog", dialog_window);
    print_window("active", info.hwndActive);
    print_window("focus", info.hwndFocus);
    if (argc == 2) return 0;

    UINT key = (UINT)wcstoul(argv[2], NULL, 0);
    HWND target = info.hwndFocus ? info.hwndFocus : dialog_window;
    DWORD_PTR ignored = 0;
    if (!SendMessageTimeoutW(target, WM_KEYDOWN, key, 0,
                             SMTO_ABORTIFHUNG | SMTO_BLOCK, 1000, &ignored)) return 4;
    if (!SendMessageTimeoutW(target, WM_KEYUP, key, 0,
                             SMTO_ABORTIFHUNG | SMTO_BLOCK, 1000, &ignored)) return 5;
    return 0;
}
