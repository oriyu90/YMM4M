#define UNICODE
#define _UNICODE
#include <windows.h>
#include <stdio.h>
#include <wchar.h>

static HWND blank_window;

static BOOL CALLBACK find_blank_window(HWND window, LPARAM unused) {
    (void)unused;
    wchar_t title[256] = {0};
    wchar_t class_name[512] = {0};
    GetWindowTextW(window, title, 256);
    GetClassNameW(window, class_name, 512);
    if (IsWindowVisible(window) && !title[0]
            && wcsstr(class_name, L"HwndWrapper[YukkuriMovieMaker;")) {
        blank_window = window;
        return FALSE;
    }
    return TRUE;
}

static BOOL send_message(HWND target, UINT message, WPARAM wparam) {
    DWORD_PTR result = 0;
    return SendMessageTimeoutW(target, message, wparam, 0,
                               SMTO_ABORTIFHUNG | SMTO_BLOCK, 1000, &result) != 0;
}

int wmain(int argc, wchar_t **argv) {
    if (argc != 2) return 1;
    EnumWindows(find_blank_window, 0);
    if (!blank_window) return 2;

    DWORD thread = GetWindowThreadProcessId(blank_window, NULL);
    GUITHREADINFO info = {.cbSize = sizeof(info)};
    HWND target = GetGUIThreadInfo(thread, &info) && info.hwndFocus
        ? info.hwndFocus : blank_window;
    printf("dialog=%p focus=%p target=%p\n",
           (void *)blank_window, (void *)info.hwndFocus, (void *)target);
    for (const wchar_t *cursor = argv[1]; *cursor; ++cursor) {
        if (!send_message(target, WM_CHAR, *cursor)) return 3;
    }
    if (!send_message(target, WM_KEYDOWN, VK_RETURN)) return 4;
    if (!send_message(target, WM_KEYUP, VK_RETURN)) return 5;
    return 0;
}
