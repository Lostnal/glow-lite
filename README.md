# Glow Lite

一个只在菜单栏/灵动岛里出现的 macOS 小工具：开关带 **PROLED XDR 显示屏**的 MacBook Pro 上盖那颗发光的 Apple Logo。

基于 macOS 27.3 的原生 **Live Activity**（ActivityKit + WidgetKit），没有自绘悬浮窗。

![灵动岛展开态](screenshots/island.png)

> 非 Apple 官方产品，与 Apple Inc. 无任何关联。Apple Logo 是 Apple Inc. 的商标；本项目仅用于个人设备。

## 功能

- **原生 Live Activity**：macOS 27.3+ 在菜单栏和灵动岛里显示当前状态；紧凑态是「苹果 + 关/开」。
- **点程序坞图标**：启动/刷新活动；点一下灵动岛展开，里面只有一颗大苹果，**点苹果切换**（没有滑块）。
- **关闭规则**：
  - 点苹果后 **3 秒**下岛，以最后一次点击为准（连续点会重新计时）；
  - 上岛后 **15 秒**没有任何点击，自动下岛；
  - 点黑色背景/其他区域，按系统行为立即收起。
- **程序坞右键**：只显示当前可用的那一个动作（亮着只有「关灯」，灭着只有「开灯」），外加「设置…」「显示灵动岛活动」「退出」。
- **设置**：选择「在程序坞显示」或「仅在菜单栏显示」。
- **调试菜单**：预览星空黑 / 银白机身，或跟随本机颜色。

## 环境要求

- **macOS 27.3+**（Live Activity / Dynamic Island API 目前仅在 27.3 Beta 中提供，正式版预计 12 月）。
- **Apple Silicon（arm64）**。
- 带 **PROLED XDR 显示屏**的 MacBook Pro 才有可见的发光 Logo；其他 Mac 上 App 能运行，但开关没有可见效果。
- 构建需要 **Xcode 27.3+**（含 macOS 27.3 SDK）。
- Widget Extension 建议用 **Apple Development 证书**签名；ad-hoc 签名时系统可能不加载 Live Activity 扩展（表现为灵动岛不出现）。

## 构建

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
CODESIGN_ID="Apple Development: Your Name (TEAMID)" \
./build.sh
```

- 不传 `DEVELOPER_DIR` 时会依次尝试 `xcode-select -p`、`/Applications/Xcode-beta.app`、`/Applications/Xcode.app`，并校验 macOS SDK ≥ 27.3。
- `CODESIGN_ID` 默认 `-`（ad-hoc）。想看到灵动岛，请传真实的 Apple Development 证书名（`security find-identity -v -p codesigning` 可查）。
- 产物：`dist/Glow Lite.app`。

安装：

```bash
ditto "dist/Glow Lite.app" "/Applications/Glow Lite.app"
open "/Applications/Glow Lite.app"
```

## 首次运行与免密助手

App 第一次启动时会请求一次管理员授权，安装一个固定的小助手：

| 路径 | 作用 |
| --- | --- |
| `/usr/local/libexec/logolight-helper` | root 所有的脚本，只接受 `read` / `toggle`，只修改 `com.apple.CoreBrightness` 的 `LEBacklightMode` |
| `/private/etc/sudoers.d/logolight` | `你的用户名 ALL=(root) NOPASSWD: /usr/local/libexec/logolight-helper`，只放行这一条命令 |

安装时会用 `visudo -cf` 校验语法。之后 App 用 `sudo -n` 静默调用。

- 如果拒绝授权，App 会退回「每次点击都弹一次管理员授权」；菜单「启用免密切换（管理员授权）…」可重新安装。
- 彻底移除：

```bash
sudo rm -f /usr/local/libexec/logolight-helper /private/etc/sudoers.d/logolight
```

> 这会为当前用户增加一条免密 sudo 规则（仅限上述脚本）。不能接受的话，用完上面的命令卸载即可。

## 原理

严格对应 Apple 支持文档 [149248](https://support.apple.com/zh-cn/149248)：

| 动作 | 命令 |
| --- | --- |
| 关灯 | `sudo defaults write com.apple.CoreBrightness LEBacklightMode -int 0` |
| 开灯 | `sudo defaults delete com.apple.CoreBrightness LEBacklightMode` |

助手在同一个 root 进程里完成「读取当前值 → 反向切换 → 回读校验」，再把结果返回给 App。

App 本身不沙盒（需要调用 sudo 助手）；Widget Extension 是沙盒的（`com.apple.security.app-sandbox`），通过 App Intents 把点击事件交回 App。

## 分发说明

- 直接把自己构建的 App 发给别人，对方 Gatekeeper 默认会拦（Apple Development 证书只适合本机/同 Team 设备）。
- 要对外分发二进制，需要 **Developer ID Application** 证书 + hardened runtime + Apple 公证（notarytool），并把 Bundle ID 换成你自己注册的；`build.sh` 对 `Developer ID Application` 开头的证书会自动加 `--options runtime --timestamp`。
- 具体步骤见 [docs/RELEASE.md](docs/RELEASE.md)，或直接运行：

```bash
CODESIGN_ID="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="glow-lite" \
./release.sh
```

- App Store 不适合本项目：需要 root、要安装 sudoers 文件，过不了沙盒审核。
- 公开分发前建议把 App 图标里的 Apple Logo 换成通用图标，避免商标问题。

## 源码结构

| 文件 | 作用 |
| --- | --- |
| `Sources/main.swift` | AppDelegate：Live Activity 生命周期、Dock/菜单栏菜单、设置、倒计时 |
| `Sources/Shared/LogoActivity.swift` | ActivityAttributes、App Intent、App 与扩展的桥 |
| `Sources/Widget/GlowWidget.swift` | Widget Bundle、紧凑/展开/菜单栏视图 |
| `Sources/Helper.swift` | 免密助手安装、调用、兜底授权 |
| `Sources/IconArt.swift` | App 图标与机盖绘制、机身颜色读取 |
| `Sources/SettingsWindow.swift` | 程序坞/菜单栏常驻设置 |
| `Sources/LocalizedText.swift` | 关/开 的本地化 |
| `Tools/gen_icon.swift` | 构建时生成 AppIcon.iconset |
| `build.sh` | 一键构建、生成 App Intents 元数据、签名 |

构建时会给 App 和 Widget Extension 分别生成 `Metadata.appintents`；没有它，灵动岛里的按钮不可点击。

## 已知限制

- 灵动岛的展开是**系统手势**触发的，App 没有公开 API 强制展开；点 Dock 后先出现紧凑态，需要点一下展开。
- 15 秒计时从活动出现开始；系统不会把「展开/收起」手势事件暴露给 App。
- 仅支持 macOS 27.3+，且需要 OLED 触屏 MacBook Pro 才能看到 Logo 灯效果。

## License

MIT，见 [LICENSE](LICENSE)。
