#define UNICODE
#define _UNICODE
#include <windows.h>
#include <stdio.h>
#include <string.h>
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

int main(int argc, char **argv) {
    LONG x_offset;
    if (argc != 2) return 1;
    if (!strcmp(argv[1], "video")) x_offset = 266;
    else if (!strcmp(argv[1], "audio")) x_offset = 287;
    else if (!strcmp(argv[1], "image")) x_offset = 311;
    else return 1;

    EnumWindows(find_main_window, 0);
    if (!main_window) return 2;
    ShowWindow(main_window, SW_RESTORE);
    SetForegroundWindow(main_window);

    RECT client = {0};
    POINT origin = {0, 0};
    GetClientRect(main_window, &client);
    ClientToScreen(main_window, &origin);
    LONG height = client.bottom - client.top;
    printf("kind=%s client=%ldx%ld click=%ld,%ld\n", argv[1],
           client.right - client.left, height, origin.x + x_offset, origin.y + height - 102);
    click_at(origin.x + x_offset, origin.y + height - 102);
    Sleep(1500);
    return 0;
}
