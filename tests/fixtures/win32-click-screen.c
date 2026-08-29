#include <windows.h>
#include <stdlib.h>

int main(int argc, char **argv) {
    if (argc != 3) return 1;
    SetCursorPos(strtol(argv[1], NULL, 10), strtol(argv[2], NULL, 10));
    INPUT input = {0};
    input.type = INPUT_MOUSE;
    input.mi.dwFlags = MOUSEEVENTF_LEFTDOWN;
    if (SendInput(1, &input, sizeof(input)) != 1) return 2;
    input.mi.dwFlags = MOUSEEVENTF_LEFTUP;
    return SendInput(1, &input, sizeof(input)) == 1 ? 0 : 3;
}
