# 发布二进制（Developer ID + 公证）

> 需要 **付费 Apple Developer Program**（$99/年）。免费的 Personal Team 只能创建 `Apple Development` 证书，不能做 Developer ID 分发。

## 1. 准备证书与凭据

1. 在 Xcode → Settings → Accounts → Manage Certificates，或 developer.apple.com 创建 **Developer ID Application** 证书，安装到钥匙串。
2. 生成 App 专用密码（appleid.apple.com），保存 notarytool 凭据：

```bash
xcrun notarytool store-credentials "glow-lite" \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"
```

## 2. 构建 + 公证

```bash
CODESIGN_ID="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="glow-lite" \
./release.sh
```

产物：

- `dist/Glow Lite-1.0.dmg`
- `dist/Glow Lite-1.0.dmg.sha256`

`build.sh` 会对 `Developer ID Application*` 证书自动加 `--options runtime --timestamp`。

## 3. 上传 GitHub Release

```bash
git tag v1.0.0
git push origin v1.0.0
gh release create v1.0.0 \
  "dist/Glow Lite-1.0.dmg" \
  "dist/Glow Lite-1.0.dmg.sha256" \
  --title "Glow Lite 1.0" \
  --notes "macOS 27.3+ / Apple Silicon / PROLED XDR MacBook Pro"
```

## 4. 发布前检查

- 在一台 **没装过本项目**、Gatekeeper 开启的 Mac 上：下载 → 打开 DMG → 拖进 Applications → 首次启动，确认没有“无法验证开发者”。
- 确认 Widget Extension 能加载（灵动岛出现、App Intents 按钮可点）；如果扩展没有正确签名/描述文件，可能不加载。
- 确认 Bundle ID 是你自己的（建议改掉 `com.local.glowlite`）。
- 公开分发前把 Apple Logo 图标换成非商标图标。
- macOS 27.3 目前是 Beta；正式发布建议等 27.3 正式版 SDK 重新构建，并重新公证。
- 首次运行会安装 sudoers 助手；README 里已有安全说明和卸载命令。

## 常见问题

- `notarytool` 被拒：用 `xcrun notarytool log <submission-id> --keychain-profile glow-lite` 查看原因，常见是缺 hardened runtime、未签名嵌套代码、或扩展签名不一致。
- `spctl` 不通过：确认 DMG 已 staple，App 和 `GlowWidget.appex` 都是同一 Team 的 Developer ID 签名。
- 扩展不加载：检查 `GlowWidget.appex` 的签名/entitlements；必要时用 Xcode 自动签名生成 Developer ID provisioning profile。
