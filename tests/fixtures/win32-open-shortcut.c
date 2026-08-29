#define UNICODE
#define _UNICODE
#include <windows.h>
#include <wchar.h>

static HWND main_window;

static BOOL CALLBACK find_main_window(HWND window, LPARAM unused) {
    (void)unused;
    wchar_t title[256] = {0};
    GetWindowTextW(window, title, 256);
    if (wcsstr(title, L"v4.55.1.1 Lite")) {
        main_window = window;
        return FALSE;
    }
    return TRUE;
}

static void key(WORD virtual_key, DWORD flags) {
    INPUT input = {0};
    input.type = INPUT_KEYBOARD;
    input.ki.wVk = virtual_key;
    input.ki.dwFlags = flags;
    SendInput(1, &input, sizeof(input));
}

int main(void) {
    EnumWindows(find_main_window, 0);
    if (!main_window) return 2;
    ShowWindow(main_window, SW_RESTORE);
    SetForegroundWindow(main_window);
    Sleep(200);
    key(VK_CONTROL, 0);
    key('O', 0);
    key('O', KEYEVENTF_KEYUP);
    key(VK_CONTROL, KEYEVENTF_KEYUP);
    Sleep(1000);
    return 0;
}
