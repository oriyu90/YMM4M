#include <windows.h>
#include <stdlib.h>

int main(int argc, char **argv) {
    if (argc != 3) return 1;
    SetCursorPos(strtol(argv[1], NULL, 10), strtol(argv[2], NULL, 10));

    INPUT input[4] = {0};
    input[0].type = INPUT_KEYBOARD;
    input[0].ki.wVk = VK_CONTROL;
    input[1].type = INPUT_MOUSE;
    input[1].mi.dwFlags = MOUSEEVENTF_MIDDLEDOWN;
    input[2].type = INPUT_MOUSE;
    input[2].mi.dwFlags = MOUSEEVENTF_MIDDLEUP;
    input[3].type = INPUT_KEYBOARD;
    input[3].ki.wVk = VK_CONTROL;
    input[3].ki.dwFlags = KEYEVENTF_KEYUP;
    return SendInput(4, input, sizeof(INPUT)) == 4 ? 0 : 2;
}
