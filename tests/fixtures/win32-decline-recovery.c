#define UNICODE
#define _UNICODE
#include <windows.h>

int main(void) {
    HWND confirmation = FindWindowW(L"#32770", L"確認");
    if (!confirmation) confirmation = FindWindowW(L"#32770", L"Confirm");
    if (!confirmation) return 2;
    HWND no_button = GetDlgItem(confirmation, IDNO);
    if (!no_button) return 3;
    SendMessageW(no_button, BM_CLICK, 0, 0);
    Sleep(1500);
    return 0;
}
