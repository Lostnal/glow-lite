#!/bin/bash
# 用 Developer ID 构建、签名、公证并生成可分发的 DMG。
# 需要：Developer ID Application 证书、notarytool 凭据、macOS 27.3+ SDK。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="Glow Lite"
CODESIGN_ID="${CODESIGN_ID:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
VERSION="${VERSION:-$(plutil -extract CFBundleShortVersionString raw -o - "$ROOT/Info.plist" 2>/dev/null || echo 1.0)}"

if [[ -z "$CODESIGN_ID" || "$CODESIGN_ID" != Developer\ ID\ Application:* ]]; then
    echo "错误：CODESIGN_ID 必须是 Developer ID Application 证书。" >&2
    echo "  例：CODESIGN_ID=\"Developer ID Application: Your Name (TEAMID)\"" >&2
    exit 1
fi
if [[ -z "$NOTARY_PROFILE" ]]; then
    echo "错误：请设置 NOTARY_PROFILE（notarytool 的 keychain profile 名）。" >&2
    echo "  先执行：xcrun notarytool store-credentials \"glow-lite\" --apple-id ... --team-id ... --password ..." >&2
    exit 1
fi

echo "==> 构建（Developer ID）"
CODESIGN_ID="$CODESIGN_ID" "$ROOT/build.sh"

APP="$ROOT/dist/$APP_NAME.app"
DMG="$ROOT/dist/$APP_NAME-$VERSION.dmg"
STAGE="$ROOT/dist/dmg-stage"

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> 制作 DMG"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
ditto "$APP" "$STAGE/$APP_NAME.app"
cp "$ROOT/README.md" "$ROOT/LICENSE" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"

echo "==> 签名 DMG"
/usr/bin/codesign --force --timestamp --sign "$CODESIGN_ID" "$DMG"
/usr/bin/codesign --verify --verbose=2 "$DMG"

echo "==> 提交公证（可能需要几分钟）"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Staple"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo "==> Gatekeeper 验证"
spctl -a -vvv -t open --context context:primary-signature "$DMG" || true

echo "==> 校验和"
shasum -a 256 "$DMG" | tee "$DMG.sha256"

echo
echo "完成：$DMG"
echo "上传到 GitHub Release 时同时上传 .sha256 文件。"
