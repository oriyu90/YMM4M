#define UNICODE
#define _UNICODE
#include <windows.h>
#include <stdio.h>
#include <wchar.h>

static BOOL CALLBACK click_no(HWND window, LPARAM unused) {
    (void)unused;
    wchar_t text[64] = {0};
    GetWindowTextW(window, text, 64);
    if (wcscmp(text, L"&No") == 0) {
        SendMessageW(window, BM_CLICK, 0, 0);
        return FALSE;
    }
    return TRUE;
}

static BOOL CALLBACK click_ok(HWND window, LPARAM unused) {
    (void)unused;
    wchar_t text[64] = {0};
    GetWindowTextW(window, text, 64);
    if (wcscmp(text, L"OK") == 0) {
        SendMessageW(window, BM_CLICK, 0, 0);
        return FALSE;
    }
    return TRUE;
}

static void key(WORD virtual_key, DWORD flags) {
    INPUT input = {0};
    input.type = INPUT_KEYBOARD;
    input.ki.wVk = virtual_key;
    input.ki.dwFlags = flags;
    SendInput(1, &input, sizeof(input));
}

static void print_utf8(const wchar_t *value) {
    int size = WideCharToMultiByte(CP_UTF8, 0, value, -1, NULL, 0, NULL, NULL);
    char *buffer = HeapAlloc(GetProcessHeap(), 0, (SIZE_T)size);
    if (!buffer) return;
    WideCharToMultiByte(CP_UTF8, 0, value, -1, buffer, size, NULL, NULL);
    fputs(buffer, stdout);
    HeapFree(GetProcessHeap(), 0, buffer);
}

int main(void) {
    SetConsoleOutputCP(CP_UTF8);
    HWND confirmation = FindWindowW(L"#32770", L"Confirm");
    if (!confirmation) confirmation = FindWindowW(L"#32770", L"確認");
    if (confirmation) {
        HWND no_button = GetDlgItem(confirmation, IDNO);
        if (no_button) SendMessageW(no_button, BM_CLICK, 0, 0);
        else EnumChildWindows(confirmation, click_no, 0);
    }
    Sleep(500);
    HWND notification = FindWindowW(L"#32770", L"Notification");
    if (!notification) notification = FindWindowW(L"#32770", L"通知");
    if (notification) EnumChildWindows(notification, click_ok, 0);
    Sleep(500);
    HWND exception = FindWindowW(NULL, L"An exception occurred");
    if (!exception) return 2;
    SetForegroundWindow(exception);
    Sleep(200);
    key(VK_CONTROL, 0);
    key('C', 0);
    key('C', KEYEVENTF_KEYUP);
    key(VK_CONTROL, KEYEVENTF_KEYUP);
    Sleep(500);
    if (!OpenClipboard(NULL)) return 3;
    HANDLE handle = GetClipboardData(CF_UNICODETEXT);
    if (!handle) { CloseClipboard(); return 4; }
    const wchar_t *text = GlobalLock(handle);
    if (text) { print_utf8(text); GlobalUnlock(handle); }
    CloseClipboard();
    return 0;
}
