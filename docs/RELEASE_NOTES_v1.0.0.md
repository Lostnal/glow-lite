# Glow Lite 1.0.0

Native **Live Activity / Dynamic Island** control for the glowing Apple logo on **PROLED XDR** MacBook Pros.

## Highlights

- Tap the Apple in the expanded island to toggle the light.
- Dismisses **3 seconds after the last tap**, or after **15 seconds** of inactivity.
- Compact island shows the current state.
- Dock and menu-bar-only modes.
- Space black / silver enclosure preview.
- Offline, no analytics.

## Why is this release source-only?

This release intentionally contains **source code only**:

- The Widget Extension must be signed; ad-hoc builds often do not load it.
- Shipping a double-clickable binary to other Macs requires a paid Apple Developer account, Developer ID signing, and notarization, which this project does not have.
- macOS 27.3 is still in beta, and the visible effect only exists on PROLED XDR MacBook Pros.

Build from source with an Apple Development certificate. `release.sh` can produce a notarized DMG if you have a Developer ID certificate.

## Requirements

- macOS **27.3+** (currently beta)
- Apple Silicon
- A **PROLED XDR** MacBook Pro for the visible effect
- Xcode **27.3+** to build

Not affiliated with Apple Inc. Apple logo is a trademark of Apple Inc.
