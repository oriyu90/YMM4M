#define INITGUID
#include <windows.h>
#include <dwrite.h>
#include <dwrite_2.h>
#include <cstdio>
#include <cwchar>

class analysis_source final : public IDWriteTextAnalysisSource {
public:
    explicit analysis_source(const wchar_t *locale_name) : locale(locale_name) {}

    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void **out) override {
        if (!out) return E_POINTER;
        if (iid == __uuidof(IUnknown) || iid == __uuidof(IDWriteTextAnalysisSource)) {
            *out = this;
            AddRef();
            return S_OK;
        }
        *out = nullptr;
        return E_NOINTERFACE;
    }
    ULONG STDMETHODCALLTYPE AddRef() override { return ++refs; }
    ULONG STDMETHODCALLTYPE Release() override { return --refs; }

    HRESULT STDMETHODCALLTYPE GetTextAtPosition(UINT32 position, const WCHAR **out,
            UINT32 *length) override {
        if (!out || !length) return E_POINTER;
        const UINT32 size = static_cast<UINT32>(wcslen(text));
        if (position >= size) {
            *out = nullptr;
            *length = 0;
        } else {
            *out = text + position;
            *length = size - position;
        }
        return S_OK;
    }
    HRESULT STDMETHODCALLTYPE GetTextBeforePosition(UINT32 position, const WCHAR **out,
            UINT32 *length) override {
        if (!out || !length) return E_POINTER;
        const UINT32 size = static_cast<UINT32>(wcslen(text));
        position = position < size ? position : size;
        *out = position ? text : nullptr;
        *length = position;
        return S_OK;
    }
    DWRITE_READING_DIRECTION STDMETHODCALLTYPE GetParagraphReadingDirection() override {
        return DWRITE_READING_DIRECTION_LEFT_TO_RIGHT;
    }
    HRESULT STDMETHODCALLTYPE GetLocaleName(UINT32 position, UINT32 *length,
            const WCHAR **out) override {
        if (!length || !out) return E_POINTER;
        const UINT32 size = static_cast<UINT32>(wcslen(text));
        *length = position < size ? size - position : 0;
        *out = locale;
        return S_OK;
    }
    HRESULT STDMETHODCALLTYPE GetNumberSubstitution(UINT32 position, UINT32 *length,
            IDWriteNumberSubstitution **substitution) override {
        if (!length || !substitution) return E_POINTER;
        const UINT32 size = static_cast<UINT32>(wcslen(text));
        *length = position < size ? size - position : 0;
        *substitution = nullptr;
        return S_OK;
    }

    static constexpr const wchar_t *text = L"日本語テストABC123";

private:
    ULONG refs = 1;
    const wchar_t *locale;
};

template <typename T>
static void release(T *object) {
    if (object) object->Release();
}

static void print_family(IDWriteFont *font) {
    IDWriteFontFamily *family = nullptr;
    IDWriteLocalizedStrings *names = nullptr;
    wchar_t name[128] = L"<unavailable>";
    if (font && SUCCEEDED(font->GetFontFamily(&family))
            && SUCCEEDED(family->GetFamilyNames(&names)) && names->GetCount()) {
        UINT32 index = 0;
        BOOL exists = FALSE;
        if (SUCCEEDED(names->FindLocaleName(L"en-us", &index, &exists)) && !exists)
            index = 0;
        names->GetString(index, name, ARRAYSIZE(name));
    }
    std::wprintf(L"mapped-family=%ls\n", name);
    release(names);
    release(family);
}

static bool probe(DWRITE_FACTORY_TYPE factory_type, const wchar_t *locale) {
    IDWriteFactory *factory = nullptr;
    IDWriteFactory2 *factory2 = nullptr;
    IDWriteFontCollection *collection = nullptr;
    IDWriteFontFallback *fallback = nullptr;
    IDWriteFont *font = nullptr;
    IDWriteFontFace *face = nullptr;
    UINT32 mapped = 0;
    FLOAT scale = 0.0f;
    analysis_source source(locale);

    HRESULT hr = DWriteCreateFactory(factory_type, __uuidof(IDWriteFactory),
            reinterpret_cast<IUnknown **>(&factory));
    if (SUCCEEDED(hr)) hr = factory->QueryInterface(&factory2);
    if (SUCCEEDED(hr)) hr = factory->GetSystemFontCollection(&collection, FALSE);
    if (SUCCEEDED(hr)) hr = factory2->GetSystemFontFallback(&fallback);
    if (SUCCEEDED(hr)) hr = fallback->MapCharacters(&source, 0, 3, collection, L"Arial",
            DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STYLE_NORMAL,
            DWRITE_FONT_STRETCH_NORMAL, &mapped, &font, &scale);

    std::wprintf(L"factory=%ls locale=%ls hr=0x%08lx mapped=%u scale=%.3f font=%ls\n",
            factory_type == DWRITE_FACTORY_TYPE_SHARED ? L"shared" : L"isolated",
            locale[0] ? locale : L"<empty>", static_cast<unsigned long>(hr), mapped,
            scale, font ? L"yes" : L"no");
    print_family(font);

    const UINT32 codepoints[] = {0x65e5, 0x672c, 0x8a9e};
    UINT16 glyphs[ARRAYSIZE(codepoints)] = {};
    BOOL has[ARRAYSIZE(codepoints)] = {};
    bool complete = SUCCEEDED(hr) && font && mapped == ARRAYSIZE(codepoints);
    if (font) {
        for (UINT32 i = 0; i < ARRAYSIZE(codepoints); ++i) {
            HRESULT has_hr = font->HasCharacter(codepoints[i], &has[i]);
            complete = complete && SUCCEEDED(has_hr) && has[i];
        }
        hr = font->CreateFontFace(&face);
        if (SUCCEEDED(hr)) hr = face->GetGlyphIndices(codepoints, ARRAYSIZE(codepoints), glyphs);
        complete = complete && SUCCEEDED(hr);
        for (UINT16 glyph : glyphs) complete = complete && glyph != 0;
    }
    std::printf("has=%d,%d,%d glyphs=%u,%u,%u complete=%d\n",
            has[0], has[1], has[2], glyphs[0], glyphs[1], glyphs[2], complete);

    release(face);
    release(font);
    release(fallback);
    release(collection);
    release(factory2);
    release(factory);
    return complete;
}

int main() {
    bool ok = true;
    const wchar_t *locales[] = {L"", L"ja-JP"};
    for (const wchar_t *locale : locales) {
        ok = probe(DWRITE_FACTORY_TYPE_ISOLATED, locale) && ok;
        ok = probe(DWRITE_FACTORY_TYPE_SHARED, locale) && ok;
    }
    return ok ? 0 : 4;
}
