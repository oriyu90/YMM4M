#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#include <windows.h>
#include <stdio.h>
#include <wchar.h>

static HWND find_open_button(HWND dialog) {
    HWND button = NULL;
    HWND first_visible = NULL;
    while ((button = FindWindowExW(dialog, button, L"Button", NULL))) {
        wchar_t text[128] = {0};
        if (!IsWindowVisible(button)) continue;
        if (!first_visible) first_visible = button;
        GetWindowTextW(button, text, 128);
        if (wcsstr(text, L"開く") || wcsstr(text, L"Open")) return button;
    }
    return first_visible;
}

int wmain(int argc, wchar_t **argv) {
    HWND dialog, edit, submit;
    if (argc != 2) return 1;

    dialog = FindWindowW(L"#32770", NULL);
    if (!dialog) return 2;
    if (wcscmp(argv[1], L"--cancel") == 0) {
        SendMessageW(dialog, WM_CLOSE, 0, 0);
        Sleep(500);
        return 0;
    }
    edit = FindWindowExW(dialog, NULL, L"Edit", NULL);
    if (!edit) return 3;
    SendMessageW(edit, WM_SETTEXT, 0, (LPARAM)argv[1]);

    submit = find_open_button(dialog);
    if (!submit) return 4;
    SendMessageW(submit, BM_CLICK, 0, 0);
    Sleep(1500);
    return 0;
}
