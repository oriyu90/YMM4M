#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#include <windows.h>
#include <imm.h>
#include <stdio.h>
#include <wchar.h>

struct window_search
{
    const WCHAR *title_fragment;
    HWND result;
};

static BOOL CALLBACK find_window(HWND hwnd, LPARAM parameter)
{
    struct window_search *search = (struct window_search *)parameter;
    WCHAR title[512];

    if (!IsWindowVisible(hwnd) || !GetWindowTextW(hwnd, title, ARRAYSIZE(title)))
        return TRUE;
    if (wcsstr(title, search->title_fragment))
    {
        search->result = hwnd;
        return FALSE;
    }
    return TRUE;
}

static void print_window(const WCHAR *label, HWND hwnd)
{
    WCHAR class_name[256] = L"";
    WCHAR title[512] = L"";
    DWORD pid = 0;
    DWORD thread_id = 0;

    if (hwnd)
    {
        GetClassNameW(hwnd, class_name, ARRAYSIZE(class_name));
        GetWindowTextW(hwnd, title, ARRAYSIZE(title));
        thread_id = GetWindowThreadProcessId(hwnd, &pid);
    }

    wprintf(L"%ls=%p pid=%lu tid=%lu class=%ls title=%ls\n",
            label, hwnd, pid, thread_id, class_name, title);
}

int wmain(int argc, WCHAR **argv)
{
    HWND foreground = GetForegroundWindow();
    DWORD pid = 0;
    DWORD thread_id = GetWindowThreadProcessId(foreground, &pid);
    GUITHREADINFO gui = { .cbSize = sizeof(gui) };
    HWND focus;
    HIMC context;
    BOOL open = FALSE;
    DWORD conversion = 0;
    DWORD sentence = 0;
    COMPOSITIONFORM composition = {0};
    CANDIDATEFORM candidate = {0};
    DWORD current_thread_id = GetCurrentThreadId();
    BOOL attached = FALSE;

    if (argc == 2)
    {
        struct window_search search = { .title_fragment = argv[1] };
        EnumWindows(find_window, (LPARAM)&search);
        foreground = search.result;
        thread_id = GetWindowThreadProcessId(foreground, &pid);
    }
    else if (argc != 1)
    {
        fwprintf(stderr, L"usage: win32-ime-state-probe.exe [window-title-fragment]\n");
        return 64;
    }

    if (!foreground || !thread_id || !GetGUIThreadInfo(thread_id, &gui))
    {
        wprintf(L"GetGUIThreadInfo failed error=%lu foreground=%p tid=%lu\n",
                GetLastError(), foreground, thread_id);
        return 2;
    }

    focus = gui.hwndFocus ? gui.hwndFocus : foreground;
    if (thread_id != current_thread_id)
        attached = AttachThreadInput(current_thread_id, thread_id, TRUE);
    wprintf(L"thread_input_attached=%d error=%lu\n",
            attached, attached ? ERROR_SUCCESS : GetLastError());
    print_window(L"foreground", foreground);
    print_window(L"active", gui.hwndActive);
    print_window(L"focus", gui.hwndFocus);
    print_window(L"capture", gui.hwndCapture);
    print_window(L"caret", gui.hwndCaret);
    wprintf(L"caret_rect=%ld,%ld,%ld,%ld flags=0x%lx\n",
            gui.rcCaret.left, gui.rcCaret.top, gui.rcCaret.right, gui.rcCaret.bottom,
            gui.flags);

    context = ImmGetContext(focus);
    wprintf(L"ime_context=%p default_ime_window=%p\n",
            context, ImmGetDefaultIMEWnd(focus));
    if (!context)
    {
        if (attached) AttachThreadInput(current_thread_id, thread_id, FALSE);
        return 3;
    }

    open = ImmGetOpenStatus(context);
    wprintf(L"open=%d\n", open);
    if (ImmGetConversionStatus(context, &conversion, &sentence))
        wprintf(L"conversion=0x%lx sentence=0x%lx\n", conversion, sentence);
    else
        wprintf(L"conversion_status_error=%lu\n", GetLastError());

    if (ImmGetCompositionWindow(context, &composition))
        wprintf(L"composition_style=0x%lx point=%ld,%ld area=%ld,%ld,%ld,%ld\n",
                composition.dwStyle, composition.ptCurrentPos.x, composition.ptCurrentPos.y,
                composition.rcArea.left, composition.rcArea.top,
                composition.rcArea.right, composition.rcArea.bottom);
    else
        wprintf(L"composition_window_error=%lu\n", GetLastError());

    if (ImmGetCandidateWindow(context, 0, &candidate))
        wprintf(L"candidate_style=0x%lx index=%lu point=%ld,%ld area=%ld,%ld,%ld,%ld\n",
                candidate.dwStyle, candidate.dwIndex,
                candidate.ptCurrentPos.x, candidate.ptCurrentPos.y,
                candidate.rcArea.left, candidate.rcArea.top,
                candidate.rcArea.right, candidate.rcArea.bottom);
    else
        wprintf(L"candidate_window_error=%lu\n", GetLastError());

    ImmReleaseContext(focus, context);
    if (attached) AttachThreadInput(current_thread_id, thread_id, FALSE);
    return 0;
}
