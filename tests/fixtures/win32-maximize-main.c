#define UNICODE
#define _UNICODE
#include <windows.h>
#include <wchar.h>

static HWND main_window;

static BOOL CALLBACK find_main(HWND window, LPARAM unused) {
    (void)unused;
    wchar_t title[256] = {0};
    GetWindowTextW(window, title, 256);
    if (wcsstr(title, L"v4.55.1.1 Lite")) {
        main_window = window;
        return FALSE;
    }
    return TRUE;
}

int main(void) {
    EnumWindows(find_main, 0);
    if (!main_window) return 2;
    ShowWindow(main_window, SW_MAXIMIZE);
    return SetForegroundWindow(main_window) ? 0 : 3;
}
