#define INITGUID
#include <windows.h>
#include <dwrite.h>
#include <cstdio>
#include <cwchar>

class glyph_probe_renderer final : public IDWriteTextRenderer {
public:
    ULONG refs = 1;
    bool complete = false;

    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, void **out) override {
        if (!out) return E_POINTER;
        if (iid == __uuidof(IUnknown) || iid == __uuidof(IDWritePixelSnapping)
                || iid == __uuidof(IDWriteTextRenderer)) {
            *out = this;
            AddRef();
            return S_OK;
        }
        *out = nullptr;
        return E_NOINTERFACE;
    }
    ULONG STDMETHODCALLTYPE AddRef() override { return ++refs; }
    ULONG STDMETHODCALLTYPE Release() override { return --refs; }
    HRESULT STDMETHODCALLTYPE IsPixelSnappingDisabled(void *, BOOL *disabled) override {
        *disabled = TRUE;
        return S_OK;
    }
    HRESULT STDMETHODCALLTYPE GetCurrentTransform(void *, DWRITE_MATRIX *matrix) override {
        *matrix = DWRITE_MATRIX{1, 0, 0, 1, 0, 0};
        return S_OK;
    }
    HRESULT STDMETHODCALLTYPE GetPixelsPerDip(void *, FLOAT *pixels_per_dip) override {
        *pixels_per_dip = 1.0f;
        return S_OK;
    }
    HRESULT STDMETHODCALLTYPE DrawGlyphRun(void *, FLOAT, FLOAT, DWRITE_MEASURING_MODE,
            const DWRITE_GLYPH_RUN *run, const DWRITE_GLYPH_RUN_DESCRIPTION *, IUnknown *) override {
        std::printf("layout glyphs=%u", run->glyphCount);
        complete = run->glyphCount != 0;
        for (UINT32 i = 0; i < run->glyphCount; ++i) {
            std::printf(" %u", run->glyphIndices[i]);
            complete = complete && run->glyphIndices[i] != 0;
        }
        std::printf("\n");
        return S_OK;
    }
    HRESULT STDMETHODCALLTYPE DrawUnderline(void *, FLOAT, FLOAT,
            const DWRITE_UNDERLINE *, IUnknown *) override { return S_OK; }
    HRESULT STDMETHODCALLTYPE DrawStrikethrough(void *, FLOAT, FLOAT,
            const DWRITE_STRIKETHROUGH *, IUnknown *) override { return S_OK; }
    HRESULT STDMETHODCALLTYPE DrawInlineObject(void *, FLOAT, FLOAT, IDWriteInlineObject *,
            BOOL, BOOL, IUnknown *) override { return S_OK; }
};

template <typename T>
static void release(T *object) {
    if (object) object->Release();
}

static bool probe_family(IDWriteFontCollection *collection, const wchar_t *name) {
    UINT32 index = 0;
    BOOL exists = FALSE;
    HRESULT hr = collection->FindFamilyName(name, &index, &exists);
    std::wprintf(L"family=%ls find=0x%08lx exists=%d index=%u\n",
        name, static_cast<unsigned long>(hr), exists, index);
    if (FAILED(hr) || !exists) return false;

    IDWriteFontFamily *family = nullptr;
    IDWriteFont *font = nullptr;
    IDWriteFontFace *face = nullptr;
    hr = collection->GetFontFamily(index, &family);
    if (SUCCEEDED(hr)) hr = family->GetFirstMatchingFont(
        DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STRETCH_NORMAL,
        DWRITE_FONT_STYLE_NORMAL, &font);
    if (SUCCEEDED(hr)) hr = font->CreateFontFace(&face);

    const UINT32 codepoints[] = {0x65e5, 0x672c, 0x8a9e, 0x30c6, 0x30b9, 0x30c8, 'A'};
    UINT16 glyphs[ARRAYSIZE(codepoints)] = {};
    if (SUCCEEDED(hr)) hr = face->GetGlyphIndices(codepoints, ARRAYSIZE(codepoints), glyphs);
    std::printf("glyphs=0x%08lx", static_cast<unsigned long>(hr));
    for (UINT16 glyph : glyphs) std::printf(" %u", glyph);
    std::printf("\n");

    bool complete = SUCCEEDED(hr);
    for (UINT16 glyph : glyphs) complete = complete && glyph != 0;
    release(face);
    release(font);
    release(family);
    return complete;
}

static bool probe_layout(IDWriteFactory *factory, IDWriteFontCollection *collection,
        const wchar_t *family, const wchar_t *locale) {
    IDWriteTextFormat *format = nullptr;
    IDWriteTextLayout *layout = nullptr;
    const wchar_t text[] = L"日本語テストABC123";
    HRESULT hr = factory->CreateTextFormat(family, collection,
        DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STYLE_NORMAL,
        DWRITE_FONT_STRETCH_NORMAL, 64.0f, locale, &format);
    if (SUCCEEDED(hr)) hr = factory->CreateTextLayout(text, ARRAYSIZE(text) - 1,
        format, 1000.0f, 200.0f, &layout);
    glyph_probe_renderer renderer;
    std::wprintf(L"layout family=%ls locale=%ls\n", family,
        locale[0] ? locale : L"<empty>");
    if (SUCCEEDED(hr)) hr = layout->Draw(nullptr, &renderer, 0.0f, 0.0f);
    std::printf("layout draw=0x%08lx complete=%d\n",
        static_cast<unsigned long>(hr), renderer.complete);

    release(layout);
    release(format);
    return SUCCEEDED(hr) && renderer.complete;
}

static bool probe_gdi_font(IDWriteFactory *factory, const wchar_t *name) {
    IDWriteGdiInterop *interop = nullptr;
    IDWriteFont *font = nullptr;
    IDWriteFontFace *face = nullptr;
    LOGFONTW logfont = {};
    logfont.lfHeight = -64;
    logfont.lfWeight = FW_NORMAL;
    wcsncpy(logfont.lfFaceName, name, LF_FACESIZE - 1);

    HRESULT hr = factory->GetGdiInterop(&interop);
    if (SUCCEEDED(hr)) hr = interop->CreateFontFromLOGFONT(&logfont, &font);
    if (SUCCEEDED(hr)) hr = font->CreateFontFace(&face);
    const UINT32 codepoints[] = {0x65e5, 0x672c, 0x8a9e, 0x30c6, 0x30b9, 0x30c8, 'A'};
    UINT16 glyphs[ARRAYSIZE(codepoints)] = {};
    if (SUCCEEDED(hr)) hr = face->GetGlyphIndices(codepoints, ARRAYSIZE(codepoints), glyphs);
    std::wprintf(L"gdi family=%ls hr=0x%08lx", name, static_cast<unsigned long>(hr));
    for (UINT16 glyph : glyphs) std::wprintf(L" %u", glyph);
    std::wprintf(L"\n");

    bool complete = SUCCEEDED(hr);
    for (UINT16 glyph : glyphs) complete = complete && glyph != 0;
    release(face);
    release(font);
    release(interop);
    return complete;
}

static bool probe_factory(DWRITE_FACTORY_TYPE factory_type) {
    IDWriteFactory *factory = nullptr;
    IDWriteFontCollection *collection = nullptr;
    std::printf("factory=%s\n", factory_type == DWRITE_FACTORY_TYPE_SHARED ? "shared" : "isolated");
    HRESULT hr = DWriteCreateFactory(factory_type,
        __uuidof(IDWriteFactory), reinterpret_cast<IUnknown **>(&factory));
    if (FAILED(hr)) return false;
    hr = factory->GetSystemFontCollection(&collection, FALSE);
    if (FAILED(hr)) {
        release(factory);
        return false;
    }

    bool noto = probe_family(collection, L"Noto Sans CJK JP");
    bool ume = probe_family(collection, L"Ume UI Gothic");
    bool meiryo = probe_family(collection, L"Meiryo");

    bool layouts = true;
    const wchar_t *families[] = {L"Noto Sans CJK JP", L"Ume UI Gothic", L"Meiryo"};
    const wchar_t *locales[] = {L"ja-JP", L""};
    for (const wchar_t *family : families) {
        for (const wchar_t *locale : locales)
            layouts = probe_layout(factory, collection, family, locale) && layouts;
    }
    bool gdi = probe_gdi_font(factory, L"Meiryo");
    gdi = probe_gdi_font(factory, L"メイリオ") && gdi;

    release(collection);
    release(factory);
    return noto && ume && meiryo && layouts && gdi;
}

int main() {
    bool isolated = probe_factory(DWRITE_FACTORY_TYPE_ISOLATED);
    bool shared = probe_factory(DWRITE_FACTORY_TYPE_SHARED);
    return isolated && shared ? 0 : 4;
}
