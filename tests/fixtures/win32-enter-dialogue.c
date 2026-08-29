#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
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

static void send_unicode(const wchar_t *text) {
    for (; *text; ++text) {
        INPUT input = {0};
        input.type = INPUT_KEYBOARD;
        input.ki.wScan = *text;
        input.ki.dwFlags = KEYEVENTF_UNICODE;
        SendInput(1, &input, sizeof(input));
        input.ki.dwFlags = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
        SendInput(1, &input, sizeof(input));
    }
}

int wmain(int argc, wchar_t **argv) {
    EnumWindows(find_main_window, 0);
    if (!main_window) return 2;
    HWND voice_settings = FindWindowW(NULL, L"AquesTalk1");
    if (voice_settings) SendMessageW(voice_settings, WM_CLOSE, 0, 0);
    ShowWindow(main_window, SW_RESTORE);
    SetForegroundWindow(main_window);

    RECT client = {0};
    POINT origin = {0, 0};
    GetClientRect(main_window, &client);
    ClientToScreen(main_window, &origin);
    LONG height = client.bottom - client.top;
    LONG input_x = origin.x + 270;
    LONG row_y = origin.y + height - 38;
    LONG add_x = origin.x + 420;

    printf("client=%ldx%ld input=%ld,%ld add=%ld,%ld\n",
           client.right - client.left, height, input_x, row_y, add_x, row_y);
    if (argc == 2 && wcscmp(argv[1], L"--add-only") == 0) {
        click_at(add_x, row_y);
        Sleep(1500);
        return 0;
    }
    click_at(input_x, row_y);
    Sleep(250);
    if (argc == 2 && wcscmp(argv[1], L"--focus-only") == 0) return 0;
    send_unicode(L"日本語テストABC123");
    Sleep(250);
    click_at(add_x, row_y);
    Sleep(1500);
    return 0;
}
