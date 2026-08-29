#define UNICODE
#define _UNICODE
#include <windows.h>

static void key(WORD virtual_key, DWORD flags) {
    INPUT input = {0};
    input.type = INPUT_KEYBOARD;
    input.ki.wVk = virtual_key;
    input.ki.dwFlags = flags;
    SendInput(1, &input, sizeof(input));
}

int main(void) {
    HWND confirmation = FindWindowW(NULL, L"確認");
    if (!confirmation) confirmation = FindWindowW(NULL, L"Confirm");
    if (!confirmation) return 2;
    SetForegroundWindow(confirmation);
    Sleep(200);
    key(VK_RETURN, 0);
    key(VK_RETURN, KEYEVENTF_KEYUP);
    Sleep(1500);
    return 0;
}
