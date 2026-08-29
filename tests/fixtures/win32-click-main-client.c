#define UNICODE
#define _UNICODE
#include <windows.h>
#include <stdlib.h>
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

int main(int argc, char **argv) {
    if (argc != 3) return 1;
    EnumWindows(find_main_window, 0);
    if (!main_window) return 2;

    POINT origin = {0, 0};
    if (!ClientToScreen(main_window, &origin)) return 3;
    ShowWindow(main_window, SW_RESTORE);
    SetForegroundWindow(main_window);
    SetCursorPos(origin.x + strtol(argv[1], NULL, 10),
                 origin.y + strtol(argv[2], NULL, 10));

    INPUT input = {0};
    input.type = INPUT_MOUSE;
    input.mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
    if (SendInput(1, &input, sizeof(input)) != 1) return 4;
    input.mi.dwFlags = MOUSEEVENTF_LEFTUP;
    if (SendInput(1, &input, sizeof(input)) != 1) return 5;
    return 0;
}
