import Cocoa
import ActivityKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var finish: EnclosureFinish = .spaceBlack
    private var state: LogoLightState = .on
    private var helperReady = false
    private var busy = false
    private var residence: ResidenceMode = .dock
    private var activity: Activity<LogoActivityAttributes>?
    private var endTask: Task<Void, Never>?
    private var idleTask: Task<Void, Never>?

    private var settings: SettingsWindowController?
    private var statusItem: NSStatusItem?

    private static let stateKey = "LastLogoState"

    func applicationDidFinishLaunching(_ notification: Notification) {
        finish = IconArt.detectFinish()
        state = Self.loadState() ?? .on
        residence = ResidenceMode(rawValue: UserDefaults.standard.string(forKey: "ResidenceMode") ?? "") ?? .dock

        buildMainMenu()
        updateDockIcon()
        applyResidence(residence)

        GlowIntentBridge.toggleHandler = { [weak self] in
            self?.handleIntentToggle()
        }
        if GlowIntentBridge.pendingToggle {
            GlowIntentBridge.pendingToggle = false
            handleIntentToggle()
        }

        if ProcessInfo.processInfo.environment["LOGOLIGHT_SKIP_SETUP"] != "1" {
            startupSetup()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.showLiveActivity()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showLiveActivity()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if urls.contains(where: { $0.scheme == "glowlite" && $0.host == "toggle" }) {
            handleIntentToggle()
        }
    }

    // MARK: - 状态

    private static func loadState() -> LogoLightState? {
        guard let raw = UserDefaults.standard.string(forKey: stateKey) else { return nil }
        return LogoLightState(rawValue: raw)
    }

    private func saveState() {
        UserDefaults.standard.set(state.rawValue, forKey: Self.stateKey)
    }

    private func updateDockIcon() {
        NSApp.applicationIconImage = IconArt.appIcon(size: 512, finish: finish, state: state)
    }

    private func setState(_ newState: LogoLightState) {
        state = newState
        saveState()
        updateDockIcon()
        updateActivityState()
    }

    private func contentState() -> LogoActivityAttributes.ContentState {
        LogoActivityAttributes.ContentState(isOn: state == .on, finish: finish.rawValue)
    }

    // MARK: - Live Activity

    private func showLiveActivity() {
        if let existing = Activity<LogoActivityAttributes>.activities.first {
            activity = existing
            updateActivityState()
            scheduleIdleEnd()
            return
        }
        do {
            activity = try Activity.request(
                attributes: LogoActivityAttributes(name: "Glow Lite"),
                content: ActivityContent(state: contentState(), staleDate: nil),
                pushType: nil
            )
        } catch {
            NSLog("Glow Lite: Activity.request failed: %@", String(describing: error))
        }
        scheduleIdleEnd()
    }

    private func scheduleIdleEnd() {
        idleTask?.cancel()
        idleTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                let activities = Activity<LogoActivityAttributes>.activities
                for activity in activities {
                    Task { await activity.end(nil, dismissalPolicy: .immediate) }
                }
                self?.activity = nil
            }
        }
    }

    private func cancelIdleEnd() {
        idleTask?.cancel()
        idleTask = nil
    }

    private func updateActivityState() {
        guard let activity else { return }
        let content = ActivityContent(state: contentState(), staleDate: nil)
        Task { await activity.update(content) }
    }

    private func endActivitySoon() {
        cancelIdleEnd()
        endTask?.cancel()
        endTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                let activities = Activity<LogoActivityAttributes>.activities
                for activity in activities {
                    Task { await activity.end(nil, dismissalPolicy: .immediate) }
                }
                self?.activity = nil
            }
        }
    }

    private func handleIntentToggle() {
        toggle(fromUI: true)
    }

    // MARK: - 权限

    private func startupSetup() {
        if let actual = Helper.readState() {
            helperReady = true
            setState(actual)
            return
        }

        guard !Helper.isDeclined else { return }

        switch Helper.install() {
        case .installed:
            if let actual = Helper.readState() {
                helperReady = true
                setState(actual)
            }
        case .cancelled:
            Helper.markDeclined()
        case .failed:
            break
        }
    }

    @objc private func enableHelper() {
        guard Helper.readState() == nil else {
            helperReady = true
            return
        }
        Helper.clearDeclined()
        switch Helper.install() {
        case .installed:
            if let actual = Helper.readState() {
                helperReady = true
                setState(actual)
            }
        case .cancelled:
            Helper.markDeclined()
        case .failed:
            NSSound.beep()
        }
    }

    // MARK: - 切换

    @objc private func toggleFromMenu() {
        toggle(fromUI: false)
    }

    private func toggle(fromUI: Bool) {
        guard !busy else { return }
        busy = true
        let previous = state

        if helperReady {
            let target: LogoLightState = state == .on ? .off : .on
            setState(target)
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if let actual = Helper.toggle() {
                    self.busy = false
                    self.setState(actual)
                    if fromUI { self.endActivitySoon() }
                } else {
                    self.helperReady = false
                    self.setState(previous)
                    self.authorizedToggle(fromUI: fromUI)
                }
            }
            return
        }

        authorizedToggle(fromUI: fromUI)
    }

    private func authorizedToggle(fromUI: Bool) {
        defer { busy = false }
        switch Helper.authorizedToggle() {
        case .state(let actual):
            setState(actual)
            if fromUI { endActivitySoon() }
        case .cancelled:
            break
        case .failed:
            NSSound.beep()
        }
    }

    // MARK: - 常驻位置

    private func applyResidence(_ mode: ResidenceMode) {
        residence = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "ResidenceMode")

        switch mode {
        case .dock:
            if let statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
                self.statusItem = nil
            }
            NSApp.setActivationPolicy(.regular)
        case .menuBar:
            installStatusItem()
            NSApp.setActivationPolicy(.accessory)
        }

        settings?.setMode(mode)
    }

    private func installStatusItem() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "applelogo", accessibilityDescription: "Glow Lite")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Glow Lite"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = makeStatusMenu()
            if let button = statusItem?.button {
                menu.popUp(positioning: nil,
                           at: NSPoint(x: 0, y: button.bounds.height + 4),
                           in: button)
            }
        } else {
            showLiveActivity()
        }
    }

    // MARK: - 菜单

    private func menuItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        appItem.title = "Glow Lite"
        mainMenu.addItem(appItem)

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "关于 Glow Lite",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(menuItem("显示灵动岛活动", action: #selector(showActivityAction)))
        appMenu.addItem(menuItem("设置…", action: #selector(showSettings)))
        appMenu.addItem(menuItem("启用免密切换（管理员授权）…", action: #selector(enableHelper)))
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏 Glow Lite",
                        action: #selector(NSApplication.hide(_:)),
                        keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "退出 Glow Lite",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appItem.submenu = appMenu

        let debugItem = NSMenuItem(title: "调试", action: nil, keyEquivalent: "")
        debugItem.submenu = makeDebugMenu()
        mainMenu.addItem(debugItem)

        NSApp.mainMenu = mainMenu
    }

    private func makeDebugMenu() -> NSMenu {
        let menu = NSMenu(title: "调试")
        menu.delegate = self

        let black = menuItem("星空黑机身", action: #selector(useSpaceBlack))
        black.tag = 1
        let silver = menuItem("银白机身", action: #selector(useSilver))
        silver.tag = 2
        let follow = menuItem("跟随本机颜色", action: #selector(useDetected))
        follow.tag = 3

        menu.addItem(black)
        menu.addItem(silver)
        menu.addItem(.separator())
        menu.addItem(follow)
        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu.title == "调试" else { return }
        let raw = UserDefaults.standard.string(forKey: "EnclosureFinish")?.lowercased() ?? ""
        let activeTag: Int
        if raw == "spaceblack" || raw == "black" || raw == "star" {
            activeTag = 1
        } else if raw == "silver" || raw == "white" {
            activeTag = 2
        } else {
            activeTag = 3
        }
        for item in menu.items where item.tag != 0 {
            item.state = item.tag == activeTag ? .on : .off
        }
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(menuItem("显示灵动岛活动", action: #selector(showActivityAction)))
        menu.addItem(menuItem(state == .on ? "关灯" : "开灯", action: #selector(toggleFromMenu)))
        menu.addItem(.separator())
        menu.addItem(menuItem("设置…", action: #selector(showSettings)))

        let debugItem = NSMenuItem(title: "调试", action: nil, keyEquivalent: "")
        debugItem.submenu = makeDebugMenu()
        menu.addItem(debugItem)

        menu.addItem(.separator())
        menu.addItem(menuItem("退出", action: #selector(quit)))
        return menu
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(menuItem(state == .on ? "关灯" : "开灯", action: #selector(toggleFromMenu)))
        menu.addItem(.separator())
        menu.addItem(menuItem("显示灵动岛活动", action: #selector(showActivityAction)))
        menu.addItem(menuItem("设置…", action: #selector(showSettings)))
        menu.addItem(menuItem("退出", action: #selector(quit)))
        return menu
    }

    @objc private func showActivityAction() {
        showLiveActivity()
    }

    @objc private func showSettings() {
        if settings == nil {
            settings = SettingsWindowController(mode: residence)
            settings?.onModeChange = { [weak self] mode in
                self?.applyResidence(mode)
            }
        }
        settings?.setMode(residence)
        settings?.showWindow(nil)
        settings?.window?.center()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        if let activity {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
        NSApp.terminate(nil)
    }

    @objc private func useSpaceBlack() {
        UserDefaults.standard.set("spaceBlack", forKey: "EnclosureFinish")
        applyFinish(IconArt.detectFinish())
    }

    @objc private func useSilver() {
        UserDefaults.standard.set("silver", forKey: "EnclosureFinish")
        applyFinish(IconArt.detectFinish())
    }

    @objc private func useDetected() {
        UserDefaults.standard.removeObject(forKey: "EnclosureFinish")
        applyFinish(IconArt.detectFinish())
    }

    private func applyFinish(_ newFinish: EnclosureFinish) {
        finish = newFinish
        updateDockIcon()
        updateActivityState()
    }
}

let app = NSApplication.shared
let appDelegate = AppDelegate()
app.delegate = appDelegate
app.setActivationPolicy(.regular)
app.run()
