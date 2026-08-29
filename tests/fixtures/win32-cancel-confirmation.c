#define UNICODE
#define _UNICODE
#include <windows.h>

int main(void) {
    HWND dialog = FindWindowW(L"#32770", L"Confirm");
    if (!dialog) dialog = FindWindowW(L"#32770", L"確認");
    if (!dialog) return 2;
    HWND cancel = GetDlgItem(dialog, IDCANCEL);
    if (!cancel) return 3;
    SendMessageW(cancel, BM_CLICK, 0, 0);
    return 0;
}
