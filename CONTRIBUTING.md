# Contributing

Thanks for taking a look at Glow Lite. This is a small, hardware-specific project, so a few constraints are worth knowing before you start.

## Before you open a PR

- For bugs, include your **macOS version**, **Mac model** (`sysctl hw.model`), **Xcode version**, and whether the Widget Extension was signed.
- For UI changes, include a screenshot. The expanded island is system-rendered, so layout options are limited.
- Keep changes focused. Large refactors are easier to discuss in an issue first.

## Building

Requirements:

- macOS 27.3+ with the matching SDK
- Xcode 27.3+
- An Apple Development certificate for the Widget Extension (ad-hoc builds may not load the extension)

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
CODESIGN_ID="Apple Development: Your Name (TEAMID)" \
./build.sh
```

The build script generates App Intents metadata for both the app and the extension. If you change `ToggleLogoIntent`, rebuild both targets.

## Project layout

| Path | Purpose |
| --- | --- |
| `Sources/main.swift` | AppDelegate, activity lifecycle, menus, timers |
| `Sources/Shared/LogoActivity.swift` | Activity attributes, App Intent, app/extension bridge |
| `Sources/Widget/GlowWidget.swift` | Widget bundle, compact/expanded/menu-bar views |
| `Sources/Helper.swift` | Helper installation and fallback authorization |
| `Sources/IconArt.swift` | App icon and enclosure drawing |
| `Sources/SettingsWindow.swift` | Dock / menu-bar residence |
| `Sources/LocalizedText.swift` | On/off localization |

## Style

- Swift 5 language mode, no third-party dependencies.
- Keep UI strings localized through `LocalizedText`.
- Do not add network access, analytics, or telemetry.
- Never commit certificates, provisioning profiles, tokens, or `dist/`.

## Testing

There is no automated test suite yet. Please verify manually:

1. Build and launch the app.
2. Start the activity from the Dock; expand the island.
3. Toggle the light from the island and from the Dock menu.
4. Confirm the 3-second-after-last-tap and 15-second-idle dismissal rules.
5. Check that quitting the app ends the activity.

## Commit messages

Use short imperative subjects, for example:

- `Fix island dismissal timer`
- `Add notarized release script`
- `Localize on/off labels`
