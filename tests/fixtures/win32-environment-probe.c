#define UNICODE
#define _UNICODE
#include <windows.h>
#include <stdio.h>

int wmain(void) {
    static const wchar_t *sensitive_names[] = {
        L"CLOUDFLARE_API_TOKEN",
        L"OPENAI_API_KEY",
        L"ANTHROPIC_API_KEY",
        L"AWS_ACCESS_KEY_ID",
        L"AWS_SECRET_ACCESS_KEY",
        L"GITHUB_TOKEN",
        L"GH_TOKEN",
        L"SSH_AUTH_SOCK",
        L"DYLD_INSERT_LIBRARIES",
    };
    int leaked = 0;

    for (unsigned int i = 0; i < sizeof(sensitive_names) / sizeof(sensitive_names[0]); ++i) {
        if (GetEnvironmentVariableW(sensitive_names[i], NULL, 0)) {
            wprintf(L"leaked environment key: %ls\n", sensitive_names[i]);
            leaked = 1;
        }
    }

    if (leaked) return 2;
    puts("sensitive environment probe: passed");
    return 0;
}
