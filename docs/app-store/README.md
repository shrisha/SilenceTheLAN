# App Store Push Assets

## Regenerate everything

```bash
./Scripts/PrepareAppStoreAssets.sh
```

This command regenerates:
- Quiet-signal app icon files from source
- iPhone screenshot sets for 6.9-inch and 6.5-inch uploads

## Output files

- Icons: `docs/app-store/icons/`
  - `AppIcon-1024.png`
  - `AppIcon-Dark-1024.png`
  - `AppIcon-Tinted-1024.png`
- Screenshots:
  - `docs/app-store/screenshots/iphone-6.9/`
  - `docs/app-store/screenshots/iphone-6.5/`
- Metadata/review templates:
  - `docs/app-store/metadata/en-US.md`
  - `docs/app-store/review-notes.md`
  - `docs/app-store/release-notes.md`
  - `docs/app-store/privacy-labels.md`

## Upload checklist

1. Upload latest build from Xcode Organizer or Transporter.
2. Set app icon using `AppIcon-1024.png` if App Store Connect asks for a separate marketing icon.
3. Upload one complete screenshot set (`iphone-6.9` or `iphone-6.5`).
4. Fill store listing using `metadata/en-US.md`.
5. Paste reviewer context from `review-notes.md`.
6. Paste the current release text from `release-notes.md`.
7. Verify privacy labels, support URL, and age rating before submit.

## Note

Apple can change accepted screenshot specs. Reconfirm required sizes in App Store Connect before final submission.
