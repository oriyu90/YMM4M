#define UNICODE
#define _UNICODE
#include <windows.h>

int main(void) {
    HWND window = FindWindowW(NULL, L"AquesTalk1");
    if (!window) return 2;
    SendMessageW(window, WM_CLOSE, 0, 0);
    Sleep(500);
    return 0;
}
