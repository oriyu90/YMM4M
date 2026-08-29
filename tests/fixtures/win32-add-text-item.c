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
    EnumWindows(find_main_window, 0);
    if (!main_window) return 2;
    HWND voice_settings = FindWindowW(NULL, L"AquesTalk1");
    if (voice_settings) SendMessageW(voice_settings, WM_CLOSE, 0, 0);
    ShowWindow(main_window, SW_RESTORE);
    SetForegroundWindow(main_window);
    RECT client = {0};
    GetClientRect(main_window, &client);
    POINT origin = {0, 0};
    ClientToScreen(main_window, &origin);
    LONG width = client.right - client.left;
    LONG height = client.bottom - client.top;
    LONG x = origin.x + 242;
    LONG y = origin.y + height - 102;
    printf("client=%ldx%ld origin=%ld,%ld click=%ld,%ld\n",
           width, height, origin.x, origin.y, x, y);
    click_at(x, y);
    Sleep(1500);
    return 0;
}
