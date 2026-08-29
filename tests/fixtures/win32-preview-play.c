#define UNICODE
#define _UNICODE
#include <windows.h>
#include <stdio.h>
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

static void click_at(LONG x, LONG y) {
    SetCursorPos(x, y);
    INPUT input = {0};
    input.type = INPUT_MOUSE;
    input.mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
    SendInput(1, &input, sizeof(input));
    input.mi.dwFlags = MOUSEEVENTF_LEFTUP;
    SendInput(1, &input, sizeof(input));
}

int main(void) {
    RECT client = {0};
    POINT origin = {0, 0};

    EnumWindows(find_main_window, 0);
    if (!main_window) return 2;
    ShowWindow(main_window, SW_RESTORE);
    SetForegroundWindow(main_window);
    Sleep(500);
    GetClientRect(main_window, &client);
    ClientToScreen(main_window, &origin);
    printf("client=%ldx%ld start=%ld,%ld play=%ld,%ld\n", client.right - client.left,
           client.bottom - client.top, origin.x + 272, origin.y + 405, origin.x + 12, origin.y + 405);
    click_at(origin.x + 272, origin.y + 405);
    Sleep(200);
    click_at(origin.x + 12, origin.y + 405);
    Sleep(1500);
    return 0;
}
