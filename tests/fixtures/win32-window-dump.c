#define UNICODE
#define _UNICODE
#include <windows.h>
#include <stdio.h>

static void print_utf8(const wchar_t *value) {
    int size = WideCharToMultiByte(CP_UTF8, 0, value, -1, NULL, 0, NULL, NULL);
    if (size <= 1) return;
    char *buffer = HeapAlloc(GetProcessHeap(), 0, (SIZE_T)size);
    if (!buffer) return;
    WideCharToMultiByte(CP_UTF8, 0, value, -1, buffer, size, NULL, NULL);
    fputs(buffer, stdout);
    HeapFree(GetProcessHeap(), 0, buffer);
}

static void describe(HWND window, int depth) {
    wchar_t title[32768] = {0};
    wchar_t class_name[512] = {0};
    DWORD process_id = 0;
    RECT rect = {0};
    GetWindowThreadProcessId(window, &process_id);
    GetWindowTextW(window, title, (int)(sizeof(title) / sizeof(title[0])));
    GetClassNameW(window, class_name, (int)(sizeof(class_name) / sizeof(class_name[0])));
    GetWindowRect(window, &rect);
    for (int index = 0; index < depth; ++index) fputs("  ", stdout);
    printf("HWND=%p PID=%lu visible=%d enabled=%d owner=%p rect=%ld,%ld,%ld,%ld style=0x%lx exstyle=0x%lx class=",
           (void *)window, (unsigned long)process_id, IsWindowVisible(window), IsWindowEnabled(window),
           (void *)GetWindow(window, GW_OWNER), rect.left, rect.top, rect.right, rect.bottom,
           (unsigned long)GetWindowLongPtrW(window, GWL_STYLE),
           (unsigned long)GetWindowLongPtrW(window, GWL_EXSTYLE));
    print_utf8(class_name);
    fputs(" title=", stdout);
    print_utf8(title);
    fputc('\n', stdout);
}

static BOOL CALLBACK child_callback(HWND window, LPARAM parameter) {
    int depth = (int)parameter;
    describe(window, depth);
    EnumChildWindows(window, child_callback, (LPARAM)(depth + 1));
    return TRUE;
}

static BOOL CALLBACK window_callback(HWND window, LPARAM parameter) {
    (void)parameter;
    if (!IsWindowVisible(window)) return TRUE;
    describe(window, 0);
    EnumChildWindows(window, child_callback, 1);
    return TRUE;
}

int main(void) {
    SetConsoleOutputCP(CP_UTF8);
    EnumWindows(window_callback, 0);
    return 0;
}
