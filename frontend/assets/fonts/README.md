# Studio bundled fonts

Variable TTFs from [Google Fonts](https://fonts.google.com/) (SIL Open Font License 1.1):

| File | Family | Role |
|------|--------|------|
| `Inter-Variable.ttf` | Inter | Body / controls (legacy layering) |
| `SpaceGrotesk-Variable.ttf` | Space Grotesk | Theme default (display + UI) |
| `NotoSansSC-Variable.ttf` | Noto Sans SC | CJK fallback (zh UI, offline tests) |

Re-download:

```bash
bash scripts/download-studio-fonts.sh
```

Registered in `pubspec.yaml`; loaded via `buildStudioDarkTheme(useBundledFonts: true)` without network fetch.
