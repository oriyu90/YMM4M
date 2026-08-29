#define UNICODE
#define _UNICODE
#include <windows.h>
#include <stdio.h>

static HWND find_window_by_title_fragment(const wchar_t *fragment) {
    HWND window = NULL;
    while ((window = FindWindowExW(NULL, window, NULL, NULL))) {
        wchar_t title[256] = {0};
        GetWindowTextW(window, title, 256);
        if (wcsstr(title, fragment)) return window;
    }
    return NULL;
}

static HWND find_blank_yymm4_window(void) {
    HWND window = NULL;
    while ((window = FindWindowExW(NULL, window, NULL, NULL))) {
        wchar_t title[256] = {0};
        wchar_t class_name[512] = {0};
        GetWindowTextW(window, title, 256);
        GetClassNameW(window, class_name, 512);
        if (IsWindowVisible(window) && !title[0]
                && wcsstr(class_name, L"HwndWrapper[YukkuriMovieMaker;")) return window;
    }
    return NULL;
}

static int capture_window(HWND window, const wchar_t *path) {
    if (!window) return 2;
    RECT rect;
    if (!GetWindowRect(window, &rect)) return 3;
    int width = rect.right - rect.left;
    int height = rect.bottom - rect.top;
    HDC screen = GetDC(NULL);
    HDC memory = CreateCompatibleDC(screen);
    BITMAPINFO info = {0};
    info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    info.bmiHeader.biWidth = width;
    info.bmiHeader.biHeight = -height;
    info.bmiHeader.biPlanes = 1;
    info.bmiHeader.biBitCount = 32;
    info.bmiHeader.biCompression = BI_RGB;
    void *pixels = NULL;
    HBITMAP bitmap = CreateDIBSection(screen, &info, DIB_RGB_COLORS, &pixels, NULL, 0);
    HGDIOBJ previous = SelectObject(memory, bitmap);
    BOOL rendered = PrintWindow(window, memory, 2);
    if (!rendered) rendered = BitBlt(memory, 0, 0, width, height, screen, rect.left, rect.top, SRCCOPY);

    BITMAPFILEHEADER header = {0};
    DWORD pixel_size = (DWORD)(width * height * 4);
    header.bfType = 0x4D42;
    header.bfOffBits = sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER);
    header.bfSize = header.bfOffBits + pixel_size;
    HANDLE file = CreateFileW(path, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    DWORD written = 0;
    if (file != INVALID_HANDLE_VALUE && rendered) {
        WriteFile(file, &header, sizeof(header), &written, NULL);
        WriteFile(file, &info.bmiHeader, sizeof(info.bmiHeader), &written, NULL);
        WriteFile(file, pixels, pixel_size, &written, NULL);
        CloseHandle(file);
    }
    SelectObject(memory, previous);
    DeleteObject(bitmap);
    DeleteDC(memory);
    ReleaseDC(NULL, screen);
    return (file != INVALID_HANDLE_VALUE && rendered) ? 0 : 4;
}

static int capture(const wchar_t *title_fragment, const wchar_t *path) {
    return capture_window(find_window_by_title_fragment(title_fragment), path);
}

int main(void) {
    int first = capture(L"An exception occurred", L"Z:\\private\\tmp\\exception-window.bmp");
    int second = capture(L"v4.55.1.1 Lite", L"Z:\\private\\tmp\\main-window.bmp");
    int third = capture_window(find_blank_yymm4_window(), L"Z:\\private\\tmp\\blank-window.bmp");
    int fourth = capture(L"AquesTalk1", L"Z:\\private\\tmp\\aquestalk1-window.bmp");
    printf("exception=%d main=%d blank=%d aquestalk1=%d\n", first, second, third, fourth);
    return first ? first : second;
}
