#define UNICODE
#define _UNICODE
#include <windows.h>

int main(void) {
    HWND confirmation = FindWindowW(L"#32770", L"Confirm");
    if (!confirmation) confirmation = FindWindowW(L"#32770", L"確認");
    if (!confirmation) return 2;
    HWND yes_button = GetDlgItem(confirmation, IDYES);
    if (!yes_button) return 3;
    SendMessageW(yes_button, BM_CLICK, 0, 0);
    return 0;
}
