import AppKit

/// 机身配色（MacBook Pro 只有星空黑与银白两种）
enum EnclosureFinish: String {
    case spaceBlack
    case silver

    var displayName: String {
        switch self {
        case .spaceBlack: return "星空黑"
        case .silver: return "银白色"
        }
    }
}

/// Logo 灯状态：白苹果＝亮，黑苹果＝灭
enum LogoLightState: String {
    case on
    case off
}

/// 图标绘制：App 图标是正方形圆角块；主界面的机盖是 31 : 21.6 的合盖造型。
enum IconArt {
    /// 机盖宽高比（合盖俯视）
    static let lidAspect: CGFloat = 31.0 / 21.6
    private static let lidCornerRatio: CGFloat = 0.058
    private static let appCornerRatio: CGFloat = 0.225
    private static let appInsetRatio: CGFloat = 0.055

    // MARK: - 机身颜色读取

    /// 读取顺序：环境变量 > 用户偏好 > ioreg 的 housing-color
    static func detectFinish() -> EnclosureFinish {
        if let raw = ProcessInfo.processInfo.environment["LOGOLIGHT_FINISH"], !raw.isEmpty,
           let finish = finish(from: raw) {
            return finish
        }
        if let raw = UserDefaults.standard.string(forKey: "EnclosureFinish"), !raw.isEmpty,
           let finish = finish(from: raw) {
            return finish
        }
        if let index = housingColorIndex() {
            // 本机（Mac17,13 星空黑）housing-color 末位为 9，其余值按银白处理
            return index == 9 ? .spaceBlack : .silver
        }
        return .spaceBlack
    }

    static func housingColorIndex() -> Int? {
        guard let text = runIODeviceTree(),
              let keyRange = text.range(of: "\"housing-color\" = <") else {
            return nil
        }
        let rest = text[keyRange.upperBound...]
        guard let end = rest.firstIndex(of: ">") else { return nil }
        let hex = rest[..<end].trimmingCharacters(in: .whitespacesAndNewlines)
        guard hex.count >= 8, hex.count % 2 == 0 else { return nil }

        var bytes: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        guard bytes.count >= 4 else { return nil }
        let tail = Array(bytes.suffix(4))
        return Int(tail[0]) | Int(tail[1]) << 8 | Int(tail[2]) << 16 | Int(tail[3]) << 24
    }

    private static func runIODeviceTree() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        process.arguments = ["-l", "-p", "IODeviceTree"]
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
        return String(data: data, encoding: .utf8)
    }

    private static func finish(from raw: String) -> EnclosureFinish? {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "spaceblack", "black", "star":
            return .spaceBlack
        case "silver", "white":
            return .silver
        default:
            return nil
        }
    }

    // MARK: - 主界面机盖（31 : 21.6）

    /// 在给定矩形里画机盖：圆角矩形（机身色）+ 苹果。
    /// - Parameter appleMix: 0 = 灭灯（黑苹果），1 = 亮灯（白苹果），中间值用于点击动画。
    static func drawLid(in rect: NSRect, finish: EnclosureFinish, appleMix: CGFloat) {
        drawBody(in: rect,
                 cornerRadius: cornerRadius(forWidth: rect.width),
                 finish: finish,
                 appleMix: appleMix,
                 appleWidthRatio: 0.30,
                 appleHeightRatio: 0.44)
    }

    static func cornerRadius(forWidth width: CGFloat) -> CGFloat { width * lidCornerRatio }

    // MARK: - App 图标（正方形圆角块）

    static func appIcon(size: Int, finish: EnclosureFinish, state: LogoLightState) -> NSImage {
        let rep = appIconBitmap(size: size, finish: finish, state: state)
        let image = NSImage(size: NSSize(width: size, height: size))
        image.addRepresentation(rep)
        return image
    }

    static func appIconBitmap(size: Int, finish: EnclosureFinish, state: LogoLightState) -> NSBitmapImageRep {
        let rep = makeBitmap(size: size)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return rep }
        NSGraphicsContext.current = context

        let s = CGFloat(size)
        let inset = s * appInsetRatio
        let rect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
        let radius = s * appCornerRatio

        // 外投影
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        shadow.shadowBlurRadius = s * 0.030
        shadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)
        shadow.set()
        NSColor.black.setFill()
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
        NSGraphicsContext.restoreGraphicsState()

        drawBody(in: rect,
                 cornerRadius: radius,
                 finish: finish,
                 appleMix: state == .on ? 1 : 0,
                 appleWidthRatio: 0.44,
                 appleHeightRatio: 0.48)

        context.flushGraphics()
        return rep
    }

    // MARK: - 共用绘制

    private static func drawBody(in rect: NSRect,
                                 cornerRadius radius: CGFloat,
                                 finish: EnclosureFinish,
                                 appleMix: CGFloat,
                                 appleWidthRatio: CGFloat,
                                 appleHeightRatio: CGFloat) {
        guard rect.width > 1, rect.height > 1 else { return }
        let mix = min(max(appleMix, 0), 1)
        let body = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

        NSGraphicsContext.saveGraphicsState()
        body.addClip()

        let colors: [NSColor]
        switch finish {
        case .spaceBlack:
            colors = [NSColor(srgbRed: 0.215, green: 0.218, blue: 0.235, alpha: 1),
                      NSColor(srgbRed: 0.055, green: 0.056, blue: 0.065, alpha: 1)]
        case .silver:
            colors = [NSColor(srgbRed: 0.955, green: 0.957, blue: 0.965, alpha: 1),
                      NSColor(srgbRed: 0.795, green: 0.800, blue: 0.820, alpha: 1)]
        }
        NSGradient(colors: colors)?.draw(in: rect, angle: -90)

        // 顶部柔光
        if let sheen = NSGradient(colors: [
            NSColor.white.withAlphaComponent(finish == .spaceBlack ? 0.10 : 0.55),
            NSColor.white.withAlphaComponent(0.0),
        ]) {
            let center = NSPoint(x: rect.minX + rect.width * 0.28, y: rect.maxY - rect.height * 0.10)
            sheen.draw(fromCenter: center, radius: 0,
                       toCenter: center, radius: rect.width * 0.66,
                       options: [])
        }
        NSGraphicsContext.restoreGraphicsState()

        // 边框高光
        let rim = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5),
                               xRadius: max(0, radius - 0.5), yRadius: max(0, radius - 0.5))
        (finish == .spaceBlack ? NSColor.white.withAlphaComponent(0.10)
                               : NSColor.black.withAlphaComponent(0.12)).setStroke()
        rim.lineWidth = max(1, rect.width * 0.0045)
        rim.stroke()

        drawApple(in: rect, finish: finish, mix: mix,
                  widthRatio: appleWidthRatio, heightRatio: appleHeightRatio)
    }

    private static func drawApple(in rect: NSRect, finish: EnclosureFinish, mix: CGFloat,
                                  widthRatio: CGFloat, heightRatio: CGFloat) {
        guard let black = blackApple, let white = whiteApple else { return }

        let scale = min(rect.width * widthRatio / max(black.size.width, 1),
                        rect.height * heightRatio / max(black.size.height, 1))
        let size = NSSize(width: black.size.width * scale, height: black.size.height * scale)
        let target = NSRect(x: rect.midX - size.width / 2,
                            y: rect.midY - size.height / 2,
                            width: size.width, height: size.height)

        // 黑色苹果层（灭灯；星空黑机身补一圈极淡玻璃反光）
        NSGraphicsContext.saveGraphicsState()
        if finish == .spaceBlack {
            let rim = NSShadow()
            rim.shadowColor = NSColor.white.withAlphaComponent(0.28 * (1 - mix))
            rim.shadowBlurRadius = max(1, rect.height * 0.012)
            rim.shadowOffset = .zero
            rim.set()
        }
        black.draw(in: target, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

        guard mix > 0.001 else { return }

        // 白色苹果层（亮灯；按 mix 叠在黑苹果上，形成由黑到白的过渡）
        NSGraphicsContext.saveGraphicsState()
        let effect = NSShadow()
        if finish == .spaceBlack {
            effect.shadowColor = NSColor.white.withAlphaComponent(0.55 * mix)
            effect.shadowBlurRadius = max(1, rect.height * 0.045)
            effect.shadowOffset = .zero
        } else {
            effect.shadowColor = NSColor.black.withAlphaComponent(0.30 * mix)
            effect.shadowBlurRadius = max(1, rect.height * 0.025)
            effect.shadowOffset = NSSize(width: 0, height: -rect.height * 0.008)
        }
        effect.set()
        white.draw(in: target, from: .zero, operation: .sourceOver, fraction: mix)
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func makeBitmap(size: Int) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: size, pixelsHigh: size,
                                   bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = NSSize(width: size, height: size)
        return rep
    }

    // MARK: - 苹果图形（缓存两种颜色）

    private static let whiteApple: NSImage? = appleImage(color: .white)
    private static let blackApple: NSImage? = appleImage(color: NSColor(srgbRed: 0.035, green: 0.035, blue: 0.045, alpha: 1))

    private static func appleImage(color: NSColor) -> NSImage? {
        guard let symbol = NSImage(systemSymbolName: "applelogo", accessibilityDescription: nil) else {
            return nil
        }
        let config = NSImage.SymbolConfiguration(pointSize: 800, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        return symbol.withSymbolConfiguration(config)
    }
}
