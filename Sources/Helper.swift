import Cocoa

/// 免密小助手：一次性安装到 /usr/local/libexec + /etc/sudoers.d，
/// 之后 App 用 `sudo -n` 调用它，不再弹授权框。
/// 卸载：sudo rm -f /usr/local/libexec/logolight-helper /private/etc/sudoers.d/logolight
enum Helper {
    static let helperPath = "/usr/local/libexec/logolight-helper"
    static let sudoersPath = "/private/etc/sudoers.d/logolight"
    private static let declinedKey = "HelperDeclined"

    enum InstallResult { case installed, cancelled, failed }
    enum ToggleResult { case state(LogoLightState), cancelled, failed }

    // MARK: - 状态

    static var isDeclined: Bool { UserDefaults.standard.bool(forKey: declinedKey) }
    static func markDeclined() { UserDefaults.standard.set(true, forKey: declinedKey) }
    static func clearDeclined() { UserDefaults.standard.removeObject(forKey: declinedKey) }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: helperPath) &&
        FileManager.default.fileExists(atPath: sudoersPath)
    }

    static func readState() -> LogoLightState? {
        guard let out = run(["read"]) else { return nil }
        return parse(out)
    }

    static func toggle() -> LogoLightState? {
        guard let out = run(["toggle"]) else { return nil }
        return parse(out)
    }

    private static func parse(_ out: String) -> LogoLightState? {
        switch out {
        case "ON": return .on
        case "OFF": return .off
        default: return nil
        }
    }

    private static func run(_ arguments: [String]) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", helperPath] + arguments
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0,
              let text = String(data: data, encoding: .utf8) else { return nil }
        let out = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return out.isEmpty ? nil : out
    }

    // MARK: - 安装（启动时申请一次管理员权限）

    static func install() -> InstallResult {
        let user = sanitizedUser()
        let base64 = Data(helperScript.utf8).base64EncodedString()
        let sudoersLine = "\(user) ALL=(root) NOPASSWD: \(helperPath)"

        let steps = [
            "set -e",
            "/bin/mkdir -p /usr/local/libexec",
            "/usr/bin/printf %s '\(base64)' | /usr/bin/base64 -D > \(helperPath)",
            "/bin/chmod 0755 \(helperPath)",
            "/usr/sbin/chown root:wheel \(helperPath)",
            "T=$(/usr/bin/mktemp /tmp/logolight-sudoers.XXXXXX)",
            "/bin/echo '\(sudoersLine)' > $T",
            "/usr/sbin/visudo -cf $T >/dev/null",
            "/bin/chmod 0440 $T",
            "/usr/sbin/chown root:wheel $T",
            "/bin/mv $T \(sudoersPath)",
        ]
        let shell = steps.joined(separator: "; ")
        let prompt = "一次性安装免密小助手：只放行 Glow Lite 的 Logo 灯开关命令，可随时删除"
        let source = "do shell script \"\(shell)\" with administrator privileges with prompt \"\(prompt)\""

        guard let script = NSAppleScript(source: source) else { return .failed }
        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let code = (errorInfo[NSAppleScript.errorNumber] as? Int) ?? 0
            NSLog("Glow Lite helper install error: %@", String(describing: errorInfo))
            return code == -128 ? .cancelled : .failed
        }
        NSLog("Glow Lite helper installed: %@", isInstalled ? "yes" : "no")
        return isInstalled ? .installed : .failed
    }

    private static func sanitizedUser() -> String {
        let user = NSUserName()
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        if !user.isEmpty, user.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
            return user
        }
        return "%admin"
    }

    // MARK: - 兜底：每次点击单独授权

    static func authorizedToggle() -> ToggleResult {
        guard let script = NSAppleScript(source: toggleScript) else { return .failed }
        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let code = (errorInfo[NSAppleScript.errorNumber] as? Int) ?? 0
            return code == -128 ? .cancelled : .failed
        }
        let out = (result.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        switch out {
        case "ON": return .state(.on)
        case "OFF": return .state(.off)
        default: return .failed
        }
    }

    // MARK: - 脚本

    private static let toggleScript = #"""
    do shell script "v=$(/usr/bin/defaults read com.apple.CoreBrightness LEBacklightMode 2>/dev/null); if [ x$v = x0 ]; then /usr/bin/defaults delete com.apple.CoreBrightness LEBacklightMode >/dev/null 2>&1; rc=$?; else /usr/bin/defaults write com.apple.CoreBrightness LEBacklightMode -int 0 >/dev/null 2>&1; rc=$?; fi; if [ $rc -ne 0 ]; then /bin/echo ERROR; else v2=$(/usr/bin/defaults read com.apple.CoreBrightness LEBacklightMode 2>/dev/null); if [ x$v2 = x0 ]; then /bin/echo OFF; else /bin/echo ON; fi; fi" with administrator privileges
    """#

    private static let helperScript = #"""
    #!/bin/sh
    # Logo灯开关 helper：只处理 com.apple.CoreBrightness 的 LEBacklightMode
    set -u
    DOMAIN=com.apple.CoreBrightness
    KEY=LEBacklightMode

    case "${1:-}" in
      read)
        v=$(/usr/bin/defaults read "$DOMAIN" "$KEY" 2>/dev/null) || v=""
        if [ "$v" = "0" ]; then /bin/echo OFF; else /bin/echo ON; fi
        ;;
      toggle)
        v=$(/usr/bin/defaults read "$DOMAIN" "$KEY" 2>/dev/null) || v=""
        if [ "$v" = "0" ]; then
          /usr/bin/defaults delete "$DOMAIN" "$KEY" >/dev/null 2>&1
          rc=$?
        else
          /usr/bin/defaults write "$DOMAIN" "$KEY" -int 0 >/dev/null 2>&1
          rc=$?
        fi
        if [ $rc -ne 0 ]; then /bin/echo ERROR; exit 1; fi
        v2=$(/usr/bin/defaults read "$DOMAIN" "$KEY" 2>/dev/null) || v2=""
        if [ "$v2" = "0" ]; then /bin/echo OFF; else /bin/echo ON; fi
        ;;
      *)
        /bin/echo "usage: logolight-helper read|toggle" >&2
        exit 64
        ;;
    esac
    """#
}
