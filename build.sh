#!/bin/bash
# 构建 Glow Lite.app（原生 Live Activity / 灵动岛版本）
# 需要：Xcode 27.3+（macOS 27.3 SDK）、Apple Silicon Mac。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="Glow Lite"
WORK="$(mktemp -d /tmp/logolight-build.XXXXXX)"
BUNDLE="$WORK/$APP_NAME.app"
WIDGET="$BUNDLE/Contents/PlugIns/GlowWidget.appex"
ICONSET="$WORK/AppIcon.iconset"
DIST="$ROOT/dist/$APP_NAME.app"
CODESIGN_ID="${CODESIGN_ID:--}"

# 找一个带 macOS 27.3+ SDK 的 Xcode
DEV=""
SDK_VERSION=""
pick_dev() {
    local cand="${1:-}"
    [[ -n "$cand" && -x "$cand/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc" ]] || return 1
    local sdk="$cand/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
    [[ -d "$sdk" ]] || return 1
    local ver
    ver="$(plutil -extract Version raw -o - "$sdk/SDKSettings.plist" 2>/dev/null || true)"
    [[ -n "$ver" ]] || return 1
    if [[ "$(printf '%s\n' "27.3" "$ver" | sort -V | head -1)" != "27.3" ]]; then
        return 1
    fi
    DEV="$cand"
    SDK_VERSION="$ver"
}

CANDIDATES=()
[[ -n "${DEVELOPER_DIR:-}" ]] && CANDIDATES+=("$DEVELOPER_DIR")
[[ -n "${XCODE_APP:-}" ]] && CANDIDATES+=("$XCODE_APP/Contents/Developer")
CANDIDATES+=("$(xcode-select -p 2>/dev/null || true)")
CANDIDATES+=("/Applications/Xcode-beta.app/Contents/Developer" "/Applications/Xcode.app/Contents/Developer")
for cand in "${CANDIDATES[@]}"; do
    if pick_dev "$cand"; then break; fi
done

if [[ -z "$DEV" ]]; then
    echo "错误：没有找到带 macOS 27.3+ SDK 的 Xcode。" >&2
    echo "请安装 Xcode 27.3+，或指定 DEVELOPER_DIR=/path/to/Xcode.app/Contents/Developer" >&2
    exit 1
fi

SDK="$DEV/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
SWIFTC="$DEV/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
TOOL="$DEV/Toolchains/XcodeDefault.xctoolchain/usr/bin/appintentsmetadataprocessor"
TARGET="arm64-apple-macosx27.3"
TOOLCHAIN="$DEV/Toolchains/XcodeDefault.xctoolchain"
XCODE_VERSION="2700"

echo "==> Xcode: $DEV (macOS SDK $SDK_VERSION)"
if [[ "$CODESIGN_ID" == "-" ]]; then
    echo "提示：当前为 ad-hoc 签名；Live Activity 的 Widget Extension 建议用 Apple Development 证书签名。"
fi

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

mkdir -p "$BUNDLE/Contents/MacOS" "$BUNDLE/Contents/Resources" \
         "$WIDGET/Contents/MacOS" "$WIDGET/Contents/Resources" "$ICONSET"

echo "==> 生成图标"
mkdir -p "$WORK/gen"
cp "$ROOT/Tools/gen_icon.swift" "$WORK/gen/main.swift"
cp "$ROOT/Sources/IconArt.swift" "$WORK/gen/IconArt.swift"
"$SWIFTC" -O -swift-version 5 -target "$TARGET" -sdk "$SDK" \
    -o "$WORK/gen/gen_icon" "$WORK/gen/main.swift" "$WORK/gen/IconArt.swift"
"$WORK/gen/gen_icon" "$ICONSET"
iconutil -c icns "$ICONSET" -o "$BUNDLE/Contents/Resources/AppIcon.icns"

# 编译与 AppIntents 元数据提取在源码副本中进行，保证 const-values 相对路径可匹配
mkdir -p "$WORK/src"
cp -R "$ROOT/Sources/." "$WORK/src/"
printf '["AppIntent"]\n' > "$WORK/protocols.json"

echo "==> 构建 Widget Extension（Live Activity / Dynamic Island）"
cp "$ROOT/WidgetInfo.plist" "$WIDGET/Contents/Info.plist"
(
    cd "$WORK/src"
    "$SWIFTC" -O -wmo -swift-version 5 -target "$TARGET" -sdk "$SDK" -module-name GlowWidget \
        -parse-as-library -application-extension \
        -Xlinker -e -Xlinker _NSExtensionMain \
        -emit-const-values-path "$WORK/widget.swiftconstvalues" \
        -const-gather-protocols-list "$WORK/protocols.json" \
        -o "$WIDGET/Contents/MacOS/GlowWidget" \
        Widget/GlowWidget.swift Shared/LogoActivity.swift LocalizedText.swift \
        -framework WidgetKit -framework SwiftUI -framework ActivityKit
)

printf "Widget/GlowWidget.swift\nShared/LogoActivity.swift\nLocalizedText.swift\n" > "$WORK/widget_sources.txt"
printf "%s\n" "$WORK/widget.swiftconstvalues" > "$WORK/widget_constvals.txt"
(
    cd "$WORK/src"
    "$TOOL" --output "$WIDGET/Contents/Resources" --toolchain-dir "$TOOLCHAIN" \
        --module-name GlowWidget --sdk-root "$SDK" --xcode-version "$XCODE_VERSION" \
        --platform-family macOS --deployment-target 27.3 \
        --target-triple "$TARGET" \
        --source-file-list "$WORK/widget_sources.txt" \
        --swift-const-vals-list "$WORK/widget_constvals.txt"
)

echo "==> 构建 App"
cp "$ROOT/Info.plist" "$BUNDLE/Contents/Info.plist"
printf 'APPL????' > "$BUNDLE/Contents/PkgInfo"
(
    cd "$WORK/src"
    "$SWIFTC" -O -wmo -swift-version 5 -target "$TARGET" -sdk "$SDK" -module-name GlowLite \
        -emit-const-values-path "$WORK/app.swiftconstvalues" \
        -const-gather-protocols-list "$WORK/protocols.json" \
        -o "$BUNDLE/Contents/MacOS/GlowLite" \
        main.swift IconArt.swift Helper.swift SettingsWindow.swift Shared/LogoActivity.swift \
        -framework ActivityKit -framework AppIntents
)

printf "main.swift\nIconArt.swift\nHelper.swift\nSettingsWindow.swift\nShared/LogoActivity.swift\n" > "$WORK/app_sources.txt"
printf "%s\n" "$WORK/app.swiftconstvalues" > "$WORK/app_constvals.txt"
(
    cd "$WORK/src"
    "$TOOL" --output "$BUNDLE/Contents/Resources" --toolchain-dir "$TOOLCHAIN" \
        --module-name GlowLite --sdk-root "$SDK" --xcode-version "$XCODE_VERSION" \
        --platform-family macOS --deployment-target 27.3 \
        --target-triple "$TARGET" \
        --source-file-list "$WORK/app_sources.txt" \
        --swift-const-vals-list "$WORK/app_constvals.txt"
)

echo "==> 签名（${CODESIGN_ID}）"
xattr -c -r "$BUNDLE"
if [[ "$CODESIGN_ID" == Developer\ ID\ Application* ]]; then
    codesign --force --options runtime --timestamp --sign "$CODESIGN_ID" --entitlements "$ROOT/Widget.entitlements" "$WIDGET"
    codesign --force --options runtime --timestamp --sign "$CODESIGN_ID" "$BUNDLE"
else
    codesign --force --sign "$CODESIGN_ID" --entitlements "$ROOT/Widget.entitlements" "$WIDGET"
    codesign --force --sign "$CODESIGN_ID" "$BUNDLE"
fi
codesign -v "$BUNDLE"

echo "==> 发布到 dist"
rm -rf "$DIST"
mkdir -p "$ROOT/dist"
ditto "$BUNDLE" "$DIST"
echo "构建完成：$DIST"
