#define UNICODE
#define _UNICODE
#include <windows.h>
#include <wchar.h>

static BOOL CALLBACK find_save_button(HWND window, LPARAM parameter) {
    wchar_t text[64] = {0};
    GetWindowTextW(window, text, 64);
    if (wcscmp(text, L"Save") == 0 || wcscmp(text, L"保存") == 0) {
        *(HWND *)parameter = window;
        return FALSE;
    }
    return TRUE;
}

int wmain(int argc, wchar_t **argv) {
    HWND dialog = FindWindowW(L"#32770", NULL);
    if (!dialog) return 2;
    HWND edit = FindWindowExW(dialog, NULL, L"Edit", NULL);
    if (!edit) return 3;
    SetWindowTextW(edit, argc == 2 ? argv[1] : L"Y:\\.ymm4m-dev\\test-projects\\core-text.ymmp");
    HWND save = NULL;
    EnumChildWindows(dialog, find_save_button, (LPARAM)&save);
    if (!save) return 4;
    SendMessageW(save, BM_CLICK, 0, 0);
    Sleep(1500);
    return 0;
}
