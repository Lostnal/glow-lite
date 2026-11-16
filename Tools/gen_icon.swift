import AppKit

// 生成 AppIcon.iconset；填充色读取本机机身颜色（housing-color）
let args = CommandLine.arguments
guard args.count == 2 else {
    FileHandle.standardError.write(Data("usage: gen_icon <iconset-dir>\n".utf8))
    exit(1)
}

let outDir = URL(fileURLWithPath: args[1], isDirectory: true)
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let finish = IconArt.detectFinish()
print("机身颜色：\(finish.displayName)")

let variants: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (size, name) in variants {
    let rep = IconArt.appIconBitmap(size: size, finish: finish, state: .on)
    guard let data = rep.representation(using: .png, properties: [:]) else { exit(2) }
    try! data.write(to: outDir.appendingPathComponent(name))
}

print("icons written to \(outDir.path)")
