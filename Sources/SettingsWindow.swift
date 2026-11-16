import Cocoa

enum ResidenceMode: String {
    case dock
    case menuBar
}

/// 设置窗口：选择常驻程序坞还是菜单栏
final class SettingsWindowController: NSWindowController {
    var onModeChange: ((ResidenceMode) -> Void)?

    private let dockRadio = NSButton(radioButtonWithTitle: "在程序坞显示（Dock 图标）",
                                     target: nil, action: nil)
    private let barRadio = NSButton(radioButtonWithTitle: "仅在菜单栏显示（隐藏程序坞图标）",
                                    target: nil, action: nil)
    private var mode: ResidenceMode = .dock

    init(mode: ResidenceMode) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 196),
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: false)
        window.title = "Glow Lite 设置"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        self.mode = mode
        buildUI()
        setMode(mode)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let title = NSTextField(labelWithString: "显示位置")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.frame = NSRect(x: 24, y: 150, width: 200, height: 20)

        dockRadio.frame = NSRect(x: 24, y: 112, width: 340, height: 22)
        barRadio.frame = NSRect(x: 24, y: 80, width: 340, height: 22)
        for radio in [dockRadio, barRadio] {
            radio.target = self
            radio.action = #selector(modeChanged(_:))
        }

        let note = NSTextField(wrappingLabelWithString: "菜单栏模式下会隐藏程序坞图标；点击菜单栏图标可打开灵动岛面板，右键可打开菜单。")
        note.font = .systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor
        note.frame = NSRect(x: 24, y: 20, width: 352, height: 48)

        content.addSubview(title)
        content.addSubview(dockRadio)
        content.addSubview(barRadio)
        content.addSubview(note)
    }

    func setMode(_ mode: ResidenceMode) {
        self.mode = mode
        dockRadio.state = mode == .dock ? .on : .off
        barRadio.state = mode == .menuBar ? .on : .off
    }

    @objc private func modeChanged(_ sender: NSButton) {
        let newMode: ResidenceMode = sender === barRadio ? .menuBar : .dock
        setMode(newMode)
        onModeChange?(newMode)
    }
}
