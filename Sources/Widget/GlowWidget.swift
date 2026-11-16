import WidgetKit
import SwiftUI
import ActivityKit
import AppIntents

@main
struct GlowWidgetBundle: WidgetBundle {
    var body: some Widget {
        GlowActivityWidget()
    }
}

struct GlowActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LogoActivityAttributes.self) { context in
            GlowMenuBarContent(state: context.state)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    GlowExpandedContent(state: context.state)
                }
            } compactLeading: {
                Image(systemName: "applelogo")
            } compactTrailing: {
                Text(context.state.isOn ? LocalizedText.on : LocalizedText.off)
                    .font(.caption2)
            } minimal: {
                Image(systemName: "applelogo")
            }
        }
    }
}

// MARK: - 菜单栏里的紧凑内容

struct GlowMenuBarContent: View {
    let state: LogoActivityAttributes.ContentState

    var body: some View {
        Button(intent: ToggleLogoIntent()) {
            HStack(spacing: 6) {
                Image(systemName: "applelogo")
                    .font(.system(size: 14))
                Text(state.isOn ? LocalizedText.on : LocalizedText.off)
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 灵动岛展开内容（只有苹果，点它切换）

struct GlowExpandedContent: View {
    let state: LogoActivityAttributes.ContentState

    var body: some View {
        ZStack {
            GlowLidView(isOn: state.isOn, finish: state.finish)
                .frame(width: 240)

            Button(intent: ToggleLogoIntent()) {
                Color.clear
                    .frame(width: 56, height: 56)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(6)
    }
}

// MARK: - 机盖（31 : 21.6）

struct GlowLidView: View {
    let isOn: Bool
    let finish: String

    private var isSilver: Bool { finish == "silver" }

    private var lidColors: [Color] {
        if isSilver {
            return [Color(red: 0.955, green: 0.957, blue: 0.965),
                    Color(red: 0.795, green: 0.800, blue: 0.820)]
        }
        return [Color(red: 0.215, green: 0.218, blue: 0.235),
                Color(red: 0.055, green: 0.056, blue: 0.065)]
    }

    var body: some View {
        GeometryReader { geo in
            let s = geo.size
            let radius = s.width * 0.058
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(LinearGradient(colors: lidColors, startPoint: .top, endPoint: .bottom))
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(isSilver ? Color.black.opacity(0.12) : Color.white.opacity(0.10),
                                          lineWidth: 1)
                    )

                Image(systemName: "applelogo")
                    .font(.system(size: min(s.width * 0.30, s.height * 0.44)))
                    .foregroundStyle(isOn ? Color.white : Color(red: 0.035, green: 0.035, blue: 0.045))
                    .shadow(color: Color.white.opacity(isOn ? (isSilver ? 0.45 : 0.60) : 0.10),
                            radius: isOn ? 7 : 2)
                    .animation(.easeInOut(duration: 0.30), value: isOn)
            }
        }
        .aspectRatio(31.0 / 21.6, contentMode: .fit)
    }
}

// MARK: - 原生风格滑块（点击走 App Intent）

struct GlowSwitchView: View {
    let isOn: Bool

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let knob = h - 4
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? Color.accentColor : Color(white: 0.90))
                Circle()
                    .fill(Color.white)
                    .frame(width: knob, height: knob)
                    .padding(2)
                    .shadow(color: .black.opacity(0.20), radius: 1, y: 1)
            }
        }
    }
}
