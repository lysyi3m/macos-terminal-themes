#!/usr/bin/xcrun swift
//
// Renders a theme preview PNG straight from a .terminal file.
//
// The colors live in the plist as archived NSColor values, so no Terminal.app
// window and no manual screenshot are involved: the same theme always produces
// the same image, on any Mac.
//
// Usage:
//   ./tools/generate-preview.swift themes/Atom.terminal            # -> screenshots/atom.png
//   ./tools/generate-preview.swift themes/*.terminal               # regenerate in bulk
//   ./tools/generate-preview.swift themes/Atom.terminal -o out.png
//
import AppKit
import ImageIO

// MARK: - Palette

struct Palette {
    static let ansiKeys = [
        "ANSIBlackColor", "ANSIRedColor", "ANSIGreenColor", "ANSIYellowColor",
        "ANSIBlueColor", "ANSIMagentaColor", "ANSICyanColor", "ANSIWhiteColor",
        "ANSIBrightBlackColor", "ANSIBrightRedColor", "ANSIBrightGreenColor", "ANSIBrightYellowColor",
        "ANSIBrightBlueColor", "ANSIBrightMagentaColor", "ANSIBrightCyanColor", "ANSIBrightWhiteColor",
    ]
    static let uiKeys = ["BackgroundColor", "TextColor", "TextBoldColor", "CursorColor", "SelectionColor"]

    /// Terminal.app's built-in ANSI palette, used for keys a theme leaves undefined.
    /// Several themes define only part of the 16, and this is what Terminal shows for the rest.
    static let defaultANSI = [
        "000000", "990000", "00A600", "999900", "0000B2", "B200B2", "00A6B2", "BFBFBF",
        "666666", "E50000", "00D900", "E5E500", "0000FF", "E500E5", "00E5E5", "E5E5E5",
    ]

    let name: String
    private(set) var colors: [String: NSColor] = [:]
    /// Keys the theme file does not define. Reported so incomplete themes can be fixed.
    private(set) var missing: [String] = []

    init?(path: String) {
        guard let dict = NSDictionary(contentsOfFile: path) else { return nil }
        name = (dict["name"] as? String)
            ?? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent

        for (key, value) in dict {
            guard let key = key as? String, let data = value as? Data,
                  let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data),
                  let srgb = color.usingColorSpace(.sRGB) else { continue }
            colors[key] = srgb
        }

        // tools/iterm2terminal.swift writes the bold color under "BoldTextColor",
        // but Terminal.app reads "TextBoldColor". Accept either spelling.
        if colors["TextBoldColor"] == nil, let legacy = colors["BoldTextColor"] {
            colors["TextBoldColor"] = legacy
        }

        missing = (Palette.uiKeys + Palette.ansiKeys).filter { colors[$0] == nil }

        // Fall back so an incomplete theme still renders instead of aborting the batch.
        let background = colors["BackgroundColor"] ?? .black
        let text = colors["TextColor"] ?? .white
        colors["BackgroundColor"] = background
        colors["TextColor"] = text
        colors["TextBoldColor"] = colors["TextBoldColor"] ?? text
        colors["CursorColor"] = colors["CursorColor"] ?? text
        colors["SelectionColor"] = colors["SelectionColor"]
            ?? text.blended(withFraction: 0.7, of: background) ?? text
        for (index, key) in Palette.ansiKeys.enumerated() where colors[key] == nil {
            colors[key] = Palette.color(fromHex: Palette.defaultANSI[index])
        }
    }

    static func color(fromHex hex: String) -> NSColor {
        let value = UInt32(hex, radix: 16) ?? 0
        return NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                       green: CGFloat((value >> 8) & 0xFF) / 255,
                       blue: CGFloat(value & 0xFF) / 255,
                       alpha: 1)
    }

    func ansi(_ index: Int) -> NSColor { colors[Palette.ansiKeys[index]]! }

    var bg: NSColor { colors["BackgroundColor"]! }
    var fg: NSColor { colors["TextColor"]! }
    var bold: NSColor { colors["TextBoldColor"]! }
    var cursor: NSColor { colors["CursorColor"]! }
    var selection: NSColor { colors["SelectionColor"]! }

    /// Label color for the preview's own captions. Derived from the theme rather than
    /// taken from ANSIBrightBlack, which is pure black in many dark themes and would vanish.
    var muted: NSColor { fg.blended(withFraction: 0.5, of: bg) ?? fg }
}

// MARK: - Line model

struct Run {
    let text: String
    var color: NSColor?
    var bg: NSColor?
    var bold = false
    var italic = false
    var underline = false
}

// MARK: - Renderer

enum RenderError: Error, CustomStringConvertible {
    case contextUnavailable
    case encodingFailed
    case writeFailed(URL)

    var description: String {
        switch self {
        case .contextUnavailable: return "could not create the drawing context"
        case .encodingFailed: return "could not encode the image"
        case .writeFailed(let url): return "could not write \(url.path)"
        }
    }
}

final class PreviewRenderer {
    private let palette: Palette
    private let scale: CGFloat = 2
    private let fontSize: CGFloat = 12
    private let columns = 74
    private let padding: CGFloat = 18
    private let stripHeight: CGFloat = 7

    private let regular: NSFont
    private let boldFont: NSFont
    private let italicFont: NSFont
    private let cellWidth: CGFloat
    private let lineHeight: CGFloat

    init?(_ palette: Palette) {
        guard let regular = NSFont(name: "Menlo-Regular", size: fontSize),
              let boldFont = NSFont(name: "Menlo-Bold", size: fontSize),
              let italicFont = NSFont(name: "Menlo-Italic", size: fontSize) else { return nil }
        self.palette = palette
        self.regular = regular
        self.boldFont = boldFont
        self.italicFont = italicFont
        cellWidth = regular.maximumAdvancement.width
        lineHeight = ceil(fontSize * 1.5)
    }

    // MARK: content

    private func prompt(_ command: String) -> [Run] {
        [Run(text: "user", color: palette.ansi(2), bold: true),
         Run(text: "@", color: palette.muted),
         Run(text: "mac", color: palette.ansi(2), bold: true),
         Run(text: " ~/project", color: palette.ansi(4), bold: true),
         Run(text: " $ ", color: palette.ansi(5), bold: true),
         Run(text: command, color: palette.fg)]
    }

    private var body: [[Run]] {
        let (red, green, yellow) = (palette.ansi(1), palette.ansi(2), palette.ansi(3))
        let (blue, magenta, cyan) = (palette.ansi(4), palette.ansi(5), palette.ansi(6))
        let brBlack = palette.ansi(8)
        let (brRed, brGreen, brYellow) = (palette.ansi(9), palette.ansi(10), palette.ansi(11))
        let (brBlue, brMagenta, brCyan) = (palette.ansi(12), palette.ansi(13), palette.ansi(14))

        return [
            prompt("ls"),
            [Run(text: "README.md  ", color: palette.fg),
             Run(text: "themes/  screenshots/  ", color: blue, bold: true),
             Run(text: "build.sh  ", color: green, bold: true),
             Run(text: "latest@  ", color: cyan, bold: true),
             Run(text: "logo.png  ", color: magenta),
             Run(text: "dist.tgz", color: red)],
            [],
            prompt("git status -sb"),
            [Run(text: "## ", color: brBlack), Run(text: "master", color: brGreen),
             Run(text: "...", color: brBlack), Run(text: "origin/master", color: brRed),
             Run(text: " [ahead 1]", color: brYellow)],
            [Run(text: " M ", color: yellow), Run(text: "tools/generate-preview.swift", color: palette.fg)],
            [Run(text: "?? ", color: red), Run(text: "screenshots/", color: palette.fg)],
            [],
            prompt("./server --watch"),
            [Run(text: "12:04:07 ", color: brBlack), Run(text: " INFO  ", color: palette.bg, bg: green, bold: true),
             Run(text: " listening on ", color: palette.fg), Run(text: ":8080", color: brBlue)],
            [Run(text: "12:04:09 ", color: brBlack), Run(text: " DEBUG ", color: palette.bg, bg: blue, bold: true),
             Run(text: " cache warm, ", color: palette.fg), Run(text: "173", color: brMagenta),
             Run(text: " entries", color: palette.fg)],
            [Run(text: "12:04:11 ", color: brBlack), Run(text: " WARN  ", color: palette.bg, bg: yellow, bold: true),
             Run(text: " deprecated flag ", color: palette.fg), Run(text: "--legacy", color: brCyan)],
            [Run(text: "12:04:12 ", color: brBlack), Run(text: " ERROR ", color: palette.bg, bg: red, bold: true),
             Run(text: " connection refused", color: brRed, bold: true)],
        ]
    }

    private var legibility: [[Run]] {
        [
            [Run(text: "normal", color: palette.fg),
             Run(text: "  "),
             Run(text: "bold", color: palette.bold, bold: true),
             Run(text: "  "),
             Run(text: "dim", color: palette.ansi(8)),
             Run(text: "  "),
             Run(text: "italic", color: palette.fg, italic: true),
             Run(text: "  "),
             Run(text: "underline", color: palette.fg, underline: true),
             Run(text: "  "),
             Run(text: " inverse ", color: palette.bg, bg: palette.fg),
             Run(text: "  "),
             Run(text: "cursor ", color: palette.muted),
             Run(text: "x", color: palette.bg, bg: palette.cursor)],
            [Run(text: "selection ", color: palette.muted),
             Run(text: " selected text ", color: palette.fg, bg: palette.selection),
             Run(text: " "),
             Run(text: " selected bold ", color: palette.bold, bg: palette.selection, bold: true)],
        ]
    }

    // MARK: drawing

    private func attributed(_ run: Run) -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: run.italic ? italicFont : (run.bold ? boldFont : regular),
            .foregroundColor: run.color ?? palette.fg,
        ]
        if let bg = run.bg { attributes[.backgroundColor] = bg }
        if run.underline { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        return NSAttributedString(string: run.text, attributes: attributes)
    }

    func render(to url: URL) throws {
        let content = body
        let footer = legibility
        let contentWidth = CGFloat(columns) * cellWidth
        let width = (padding * 2 + contentWidth).rounded()

        let height = (padding
            + stripHeight + 14
            + CGFloat(content.count) * lineHeight
            + 12
            + CGFloat(footer.count) * lineHeight
            + padding).rounded()
        let size = NSSize(width: width, height: height)

        // Draw in sRGB so the pixels carry the theme's exact color values. A
        // calibratedRGB bitmap silently shifts them (#161719 lands as #121213).
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let cgContext = CGContext(
                data: nil,
                width: Int(size.width * scale), height: Int(size.height * scale),
                bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
              ) else { throw RenderError.contextUnavailable }
        cgContext.scaleBy(x: scale, y: scale)

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(cgContext: cgContext, flipped: false)

        palette.bg.setFill()
        NSRect(origin: .zero, size: size).fill()

        // Everything below positions from the top edge; AppKit draws from the bottom.
        func draw(_ string: NSAttributedString, x: CGFloat, top: CGFloat) {
            string.draw(at: NSPoint(x: x, y: size.height - top - string.size().height))
        }
        func draw(_ runs: [Run], x: CGFloat, top: CGFloat) {
            let line = NSMutableAttributedString()
            runs.forEach { line.append(attributed($0)) }
            draw(line, x: x, top: top)
        }
        func fill(x: CGFloat, top: CGFloat, width w: CGFloat, height h: CGFloat, _ color: NSColor) {
            color.setFill()
            NSRect(x: x, y: size.height - top - h, width: w, height: h).fill()
        }

        var y = padding

        // Full palette as one unlabeled strip: completeness without a color chart.
        let swatchWidth = contentWidth / 16
        for i in 0..<16 {
            fill(x: padding + CGFloat(i) * swatchWidth, top: y,
                 width: swatchWidth.rounded(.up), height: stripHeight, palette.ansi(i))
        }
        y += stripHeight + 14

        for line in content {
            if !line.isEmpty { draw(line, x: padding, top: y) }
            y += lineHeight
        }
        y += 12

        for line in footer {
            draw(line, x: padding, top: y)
            y += lineHeight
        }

        guard let image = cgContext.makeImage() else { throw RenderError.encodingFailed }

        let temporary = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).tmp")
        guard let destination = CGImageDestinationCreateWithURL(
            temporary as CFURL, "public.png" as CFString, 1, nil
        ) else { throw RenderError.writeFailed(url) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: temporary)
            throw RenderError.writeFailed(url)
        }
        do {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: temporary)
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw RenderError.writeFailed(url)
        }
    }
}

// MARK: - Entry point

/// screenshots/ filenames are the theme name lowercased, with every run of
/// non-alphanumeric characters collapsed to a single underscore.
/// "Monokai Pro (Filter Spectrum)" -> "monokai_pro_filter_spectrum"
func screenshotName(for themeURL: URL) -> String {
    let base = themeURL.deletingPathExtension().lastPathComponent.lowercased()
    var name = ""
    var pendingSeparator = false
    for character in base {
        if character.isLetter || character.isNumber {
            name.append(character)
            pendingSeparator = false
        } else if !pendingSeparator {
            name.append("_")
            pendingSeparator = true
        }
    }
    return name.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
}

// Reject a malformed command line before anything is written.
var themePaths: [String] = []
var explicitOutput: String?
var index = 0
let rawArguments = Array(CommandLine.arguments.dropFirst())

func usage() -> Never {
    print("Usage: generate-preview.swift THEME.terminal [...] [-o OUT.png]")
    exit(1)
}

while index < rawArguments.count {
    let argument = rawArguments[index]
    switch argument {
    case "-o", "--output":
        guard index + 1 < rawArguments.count else {
            print("Error: \(argument) needs a file path")
            usage()
        }
        guard explicitOutput == nil else {
            print("Error: \(argument) given more than once")
            usage()
        }
        explicitOutput = rawArguments[index + 1]
        index += 2
    default:
        guard !argument.hasPrefix("-") else {
            print("Error: unknown option \(argument)")
            usage()
        }
        themePaths.append(argument)
        index += 1
    }
}

guard !themePaths.isEmpty else { usage() }
if explicitOutput != nil && themePaths.count > 1 {
    print("Error: -o takes a single theme")
    exit(1)
}

let repoRoot = URL(fileURLWithPath: CommandLine.arguments[0])
    .resolvingSymlinksInPath()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let screenshotsDir = repoRoot.appendingPathComponent("screenshots")

// Resolve every destination up front. Two theme names can normalize to the same
// screenshot ("Foo Bar" and "Foo-Bar"), which would silently overwrite a preview.
var outputs: [URL] = []
var claimedBy: [String: String] = [:]
for path in themePaths {
    let themeURL = URL(fileURLWithPath: path)
    if let explicitOutput {
        outputs.append(URL(fileURLWithPath: explicitOutput))
        continue
    }
    let fileName = screenshotName(for: themeURL) + ".png"
    if let owner = claimedBy[fileName] {
        print("Error: \(owner) and \(path) both map to screenshots/\(fileName)")
        exit(1)
    }
    claimedBy[fileName] = path
    outputs.append(screenshotsDir.appendingPathComponent(fileName))
}

var incomplete: [String] = []
var failures = 0

for (path, output) in zip(themePaths, outputs) {
    guard let palette = Palette(path: path) else {
        print("Error: cannot read \(path)")
        failures += 1
        continue
    }
    guard let renderer = PreviewRenderer(palette) else {
        print("Error: Menlo is not available")
        exit(1)
    }
    do {
        try renderer.render(to: output)
    } catch {
        print("Error: \(path): \(error)")
        failures += 1
        continue
    }
    if !palette.missing.isEmpty {
        incomplete.append("  \(palette.name): \(palette.missing.joined(separator: ", "))")
    }
}

print("Rendered \(themePaths.count - failures) preview(s)")
if !incomplete.isEmpty {
    print("\nThemes with undefined colors (rendered with fallbacks):")
    incomplete.forEach { print($0) }
}
exit(failures == 0 ? 0 : 1)
