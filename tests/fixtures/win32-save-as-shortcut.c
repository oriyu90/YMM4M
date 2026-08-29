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
    SetForegroundWindow(main_window);
    INPUT input[6] = {0};
    input[0].type = INPUT_KEYBOARD; input[0].ki.wVk = VK_CONTROL;
    input[1].type = INPUT_KEYBOARD; input[1].ki.wVk = VK_SHIFT;
    input[2].type = INPUT_KEYBOARD; input[2].ki.wVk = 'S';
    input[3].type = INPUT_KEYBOARD; input[3].ki.wVk = 'S'; input[3].ki.dwFlags = KEYEVENTF_KEYUP;
    input[4].type = INPUT_KEYBOARD; input[4].ki.wVk = VK_SHIFT; input[4].ki.dwFlags = KEYEVENTF_KEYUP;
    input[5].type = INPUT_KEYBOARD; input[5].ki.wVk = VK_CONTROL; input[5].ki.dwFlags = KEYEVENTF_KEYUP;
    return SendInput(6, input, sizeof(INPUT)) == 6 ? 0 : 3;
}
