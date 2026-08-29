#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif

#include <windows.h>
#include <stdint.h>
#include <stdio.h>
#include <wchar.h>

#define MAX_INPUT_BYTES (64u * 1024u)

static const wchar_t tested_window_title_fragment[] = L"v4.55.1.1 Lite";
static HWND main_window;

static BOOL CALLBACK find_tested_main_window(HWND window, LPARAM unused)
{
    wchar_t title[512] = {0};
    (void)unused;
    if (!IsWindowVisible(window)) return TRUE;
    GetWindowTextW(window, title, (int)(sizeof(title) / sizeof(title[0])));
    if (wcsstr(title, tested_window_title_fragment))
    {
        main_window = window;
        return FALSE;
    }
    return TRUE;
}

static int read_utf8_file(const wchar_t *path, wchar_t **output)
{
    HANDLE file;
    LARGE_INTEGER size;
    DWORD bytes_read = 0;
    char *utf8 = NULL;
    wchar_t *wide = NULL;
    int wide_length;

    *output = NULL;
    file = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING,
                       FILE_ATTRIBUTE_NORMAL, NULL);
    if (file == INVALID_HANDLE_VALUE) return 10;
    if (!GetFileSizeEx(file, &size) || size.QuadPart <= 0 ||
        size.QuadPart > MAX_INPUT_BYTES)
    {
        CloseHandle(file);
        return 11;
    }
    utf8 = HeapAlloc(GetProcessHeap(), 0, (SIZE_T)size.QuadPart);
    if (!utf8)
    {
        CloseHandle(file);
        return 12;
    }
    if (!ReadFile(file, utf8, (DWORD)size.QuadPart, &bytes_read, NULL) ||
        bytes_read != (DWORD)size.QuadPart)
    {
        HeapFree(GetProcessHeap(), 0, utf8);
        CloseHandle(file);
        return 13;
    }
    CloseHandle(file);
    if (memchr(utf8, '\0', bytes_read))
    {
        HeapFree(GetProcessHeap(), 0, utf8);
        return 14;
    }
    wide_length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8,
                                      (int)bytes_read, NULL, 0);
    if (!wide_length)
    {
        HeapFree(GetProcessHeap(), 0, utf8);
        return 15;
    }
    wide = HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY,
                     ((SIZE_T)wide_length + 1) * sizeof(*wide));
    if (!wide)
    {
        HeapFree(GetProcessHeap(), 0, utf8);
        return 12;
    }
    if (MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, utf8,
                            (int)bytes_read, wide, wide_length) != wide_length)
    {
        HeapFree(GetProcessHeap(), 0, wide);
        HeapFree(GetProcessHeap(), 0, utf8);
        return 15;
    }
    HeapFree(GetProcessHeap(), 0, utf8);
    *output = wide;
    return 0;
}

static int click_dialogue_field(HWND window)
{
    RECT client = {0};
    POINT target = {270, 0};
    INPUT input[2] = {0};

    if (!GetClientRect(window, &client)) return 20;
    target.y = (client.bottom - client.top) - 38;
    if (target.y < 0 || !ClientToScreen(window, &target)) return 20;
    if (!SetCursorPos(target.x, target.y)) return 21;
    input[0].type = INPUT_MOUSE;
    input[0].mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
    input[1].type = INPUT_MOUSE;
    input[1].mi.dwFlags = MOUSEEVENTF_LEFTUP;
    return SendInput(2, input, sizeof(INPUT)) == 2 ? 0 : 22;
}

static int send_unicode(const wchar_t *text)
{
    for (; *text; ++text)
    {
        INPUT input[2] = {0};
        input[0].type = INPUT_KEYBOARD;
        input[0].ki.wScan = *text;
        input[0].ki.dwFlags = KEYEVENTF_UNICODE;
        input[1] = input[0];
        input[1].ki.dwFlags |= KEYEVENTF_KEYUP;
        if (SendInput(2, input, sizeof(INPUT)) != 2) return 30;
    }
    return 0;
}

int wmain(int argc, wchar_t **argv)
{
    wchar_t *text = NULL;
    int result;

    if (argc != 3 || wcscmp(argv[1], L"--commit-file") != 0) return 1;
    result = read_utf8_file(argv[2], &text);
    if (result) return result;

    EnumWindows(find_tested_main_window, 0);
    if (!main_window)
    {
        HeapFree(GetProcessHeap(), 0, text);
        return 2;
    }
    ShowWindow(main_window, SW_RESTORE);
    if (!SetForegroundWindow(main_window))
    {
        HeapFree(GetProcessHeap(), 0, text);
        return 3;
    }
    Sleep(150);
    result = click_dialogue_field(main_window);
    if (!result)
    {
        Sleep(150);
        result = send_unicode(text);
    }
    SecureZeroMemory(text, (wcslen(text) + 1) * sizeof(*text));
    HeapFree(GetProcessHeap(), 0, text);
    return result;
}
