#define UNICODE
#define _UNICODE
#include <windows.h>

int wmain(int argc, wchar_t **argv) {
    if (argc != 2) return 1;
    HWND window = FindWindowW(NULL, argv[1]);
    if (!window) return 2;
    SendMessageW(window, WM_CLOSE, 0, 0);
    return IsWindow(window) ? 3 : 0;
}
