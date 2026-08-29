#define UNICODE
#define _UNICODE
#include <windows.h>
#include <stdlib.h>
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

int main(int argc, char **argv) {
    if (argc != 3) return 1;
    EnumWindows(find_main, 0);
    if (!main_window) return 2;
    POINT point = {strtol(argv[1], NULL, 10), strtol(argv[2], NULL, 10)};
    if (!ClientToScreen(main_window, &point)) return 3;
    SetForegroundWindow(main_window);
    Sleep(200);
    SetCursorPos(point.x, point.y);

    INPUT input[4] = {0};
    input[0].type = INPUT_KEYBOARD;
    input[0].ki.wVk = VK_CONTROL;
    input[1].type = INPUT_MOUSE;
    input[1].mi.dwFlags = MOUSEEVENTF_MIDDLEDOWN;
    input[2].type = INPUT_MOUSE;
    input[2].mi.dwFlags = MOUSEEVENTF_MIDDLEUP;
    input[3].type = INPUT_KEYBOARD;
    input[3].ki.wVk = VK_CONTROL;
    input[3].ki.dwFlags = KEYEVENTF_KEYUP;
    return SendInput(4, input, sizeof(INPUT)) == 4 ? 0 : 4;
}
