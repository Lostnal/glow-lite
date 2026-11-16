import ActivityKit
import AppIntents

public struct LogoActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var isOn: Bool
        public var finish: String

        public init(isOn: Bool, finish: String) {
            self.isOn = isOn
            self.finish = finish
        }
    }

    public var name: String

    public init(name: String) {
        self.name = name
    }
}

public struct ToggleLogoIntent: AppIntent {
    public static var title: LocalizedStringResource = "切换 Logo 灯"
    public static var openAppWhenRun: Bool = true
    public static var isDiscoverable: Bool = false

    public init() {}

    public func perform() async throws -> some IntentResult {
        await MainActor.run {
            if let handler = GlowIntentBridge.toggleHandler {
                handler()
            } else {
                GlowIntentBridge.pendingToggle = true
            }
        }
        return .result()
    }
}

@MainActor
public enum GlowIntentBridge {
    public static var toggleHandler: (() -> Void)?
    public static var pendingToggle = false
}
