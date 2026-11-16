# Security Policy

## Supported versions

Only the latest `main` branch and the latest tagged release receive fixes.

## Reporting a vulnerability

Please **do not open a public issue** for security-sensitive reports.

Use GitHub's private vulnerability reporting:

<https://github.com/Lostnal/glow-lite/security/advisories/new>

Include reproduction steps, the affected macOS version, and any relevant logs. You can expect an initial response within a few days.

## Threat model

Glow Lite is a local, offline utility. It does not open network connections and does not collect telemetry.

The only privileged component is the optional helper:

- `/usr/local/libexec/logolight-helper` — a root-owned script that accepts only `read` and `toggle`
- `/private/etc/sudoers.d/logolight` — grants the installing user passwordless sudo for **that exact script only**

This means any process running as your user can toggle the logo light without a password. That is the intended convenience trade-off, but it is a real expansion of local privilege. If you do not want it:

1. decline the first-launch authorization, and the app falls back to per-click authorization; or
2. remove the helper:

```bash
sudo rm -f /usr/local/libexec/logolight-helper /private/etc/sudoers.d/logolight
```

## Scope

Issues in the following areas are in scope:

- the sudoers file or helper accepting anything beyond `read` / `toggle`
- command injection through the helper or app
- the app bundle or Widget Extension writing outside expected locations
- notarization / signing bypasses

Out of scope:

- designs that require disabling SIP
- issues that require an already-compromised admin account
- Apple beta OS behavior changes
