#!/usr/bin/xcrun swift
//
// Converts an iTerm2 .itermcolors scheme into a macOS Terminal .terminal profile.
//
// The .terminal file is written next to the source, named after it. Colors are
// archived in the color space the scheme declares, so the converted profile
// matches the original values.
//
// Usage:
//   ./tools/iterm2terminal.swift my-theme.itermcolors
//   ./tools/iterm2terminal.swift a.itermcolors b.itermcolors   # convert in bulk
//   ./tools/iterm2terminal.swift my-theme.itermcolors --force  # replace existing
//
import AppKit

// MARK: - Errors

enum ConversionError: Error, CustomStringConvertible {
    case unreadableScheme(URL)
    case notAScheme(URL)
    case destinationExists(URL)
    case invalidComponent(color: String, component: String)
    case unsupportedColorSpace(color: String, space: String)
    case archivingFailed(color: String)
    case serializationFailed
    case writeFailed(URL)

    var description: String {
        switch self {
        case .unreadableScheme(let url):
            return "cannot read \(url.lastPathComponent)"
        case .notAScheme(let url):
            return "\(url.lastPathComponent) is not an .itermcolors file"
        case .destinationExists(let url):
            return "\(url.lastPathComponent) already exists (pass --force to replace it)"
        case .invalidComponent(let color, let component):
            return "\(color) has an invalid \(component)"
        case .unsupportedColorSpace(let color, let space):
            return "\(color) uses unsupported color space \"\(space)\""
        case .archivingFailed(let color):
            return "could not archive \(color)"
        case .serializationFailed:
            return "could not serialize the profile"
        case .writeFailed(let url):
            return "could not write \(url.path)"
        }
    }
}

// MARK: - Conversion

struct ThemeConverter {
    static let colorKeys = [
        "Ansi 0 Color": "ANSIBlackColor",
        "Ansi 1 Color": "ANSIRedColor",
        "Ansi 2 Color": "ANSIGreenColor",
        "Ansi 3 Color": "ANSIYellowColor",
        "Ansi 4 Color": "ANSIBlueColor",
        "Ansi 5 Color": "ANSIMagentaColor",
        "Ansi 6 Color": "ANSICyanColor",
        "Ansi 7 Color": "ANSIWhiteColor",
        "Ansi 8 Color": "ANSIBrightBlackColor",
        "Ansi 9 Color": "ANSIBrightRedColor",
        "Ansi 10 Color": "ANSIBrightGreenColor",
        "Ansi 11 Color": "ANSIBrightYellowColor",
        "Ansi 12 Color": "ANSIBrightBlueColor",
        "Ansi 13 Color": "ANSIBrightMagentaColor",
        "Ansi 14 Color": "ANSIBrightCyanColor",
        "Ansi 15 Color": "ANSIBrightWhiteColor",
        "Background Color": "BackgroundColor",
        "Foreground Color": "TextColor",
        "Selection Color": "SelectionColor",
        // Terminal.app reads "TextBoldColor". "BoldTextColor" is silently ignored.
        "Bold Color": "TextBoldColor",
        "Cursor Color": "CursorColor",
    ]

    /// Every key Terminal.app expects a theme to define.
    static let requiredKeys = Set(colorKeys.values)

    let force: Bool

    func convert(schemeAt source: URL) throws -> [String] {
        guard source.pathExtension.lowercased() == "itermcolors" else {
            throw ConversionError.notAScheme(source)
        }
        let destination = source.deletingPathExtension().appendingPathExtension("terminal")
        if FileManager.default.fileExists(atPath: destination.path) && !force {
            throw ConversionError.destinationExists(destination)
        }
        guard let scheme = NSDictionary(contentsOf: source) else {
            throw ConversionError.unreadableScheme(source)
        }

        let name = source.deletingPathExtension().lastPathComponent
        var profile: [String: Any] = [
            "name": name,
            "type": "Window Settings",
            "ProfileCurrentVersion": 2.04,
            "columnCount": 90,
            "rowCount": 50,
        ]

        for (schemeKey, terminalKey) in ThemeConverter.colorKeys {
            guard let definition = scheme[schemeKey] as? NSDictionary else { continue }
            let color = try ThemeConverter.color(from: definition, named: schemeKey)
            guard let data = try? NSKeyedArchiver.archivedData(
                withRootObject: color, requiringSecureCoding: false
            ) else {
                throw ConversionError.archivingFailed(color: schemeKey)
            }
            profile[terminalKey] = data
        }

        try ThemeConverter.write(profile, to: destination)
        return ThemeConverter.requiredKeys.subtracting(profile.keys).sorted()
    }

    /// Builds a color in the space the scheme declares. iTerm2 omits "Color Space"
    /// only in schemes predating sRGB support, so an absent key means sRGB.
    static func color(from definition: NSDictionary, named key: String) throws -> NSColor {
        func component(_ name: String, default fallback: Double? = nil) throws -> CGFloat {
            guard let number = definition[name] as? NSNumber else {
                if let fallback { return CGFloat(fallback) }
                throw ConversionError.invalidComponent(color: key, component: name)
            }
            let value = number.doubleValue
            guard value.isFinite, (0...1).contains(value) else {
                throw ConversionError.invalidComponent(color: key, component: name)
            }
            return CGFloat(value)
        }

        let red = try component("Red Component")
        let green = try component("Green Component")
        let blue = try component("Blue Component")
        let alpha = try component("Alpha Component", default: 1)

        switch (definition["Color Space"] as? String) ?? "sRGB" {
        case "sRGB":
            return NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
        case "Calibrated":
            return NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
        case "P3", "Display P3":
            return NSColor(displayP3Red: red, green: green, blue: blue, alpha: alpha)
        case let space:
            throw ConversionError.unsupportedColorSpace(color: key, space: space)
        }
    }

    /// Writes through a temporary sibling so a failed conversion cannot leave a
    /// half-written profile in place of a good one.
    static func write(_ profile: [String: Any], to destination: URL) throws {
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: profile, format: .xml, options: 0
        ) else {
            throw ConversionError.serializationFailed
        }
        let temporary = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).tmp")
        do {
            try data.write(to: temporary, options: .atomic)
            if FileManager.default.fileExists(atPath: destination.path) {
                _ = try FileManager.default.replaceItemAt(destination, withItemAt: temporary)
            } else {
                try FileManager.default.moveItem(at: temporary, to: destination)
            }
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw ConversionError.writeFailed(destination)
        }
    }
}

// MARK: - Entry point

var schemePaths: [String] = []
var force = false

func usage() -> Never {
    print("Usage: iterm2terminal.swift SCHEME.itermcolors [...] [--force]")
    exit(1)
}

for argument in CommandLine.arguments.dropFirst() {
    switch argument {
    case "--force":
        force = true
    default:
        guard !argument.hasPrefix("-") else {
            print("Error: unknown option \(argument)")
            usage()
        }
        schemePaths.append(argument)
    }
}

guard !schemePaths.isEmpty else { usage() }

let converter = ThemeConverter(force: force)
var failures = 0

for path in schemePaths {
    let source = URL(fileURLWithPath: path).standardizedFileURL
    do {
        let missing = try converter.convert(schemeAt: source)
        let destination = source.deletingPathExtension().appendingPathExtension("terminal")
        print("Converted \(source.lastPathComponent) -> \(destination.lastPathComponent)")
        if !missing.isEmpty {
            print("  undefined colors: \(missing.joined(separator: ", "))")
        }
    } catch {
        print("Error: \(error)")
        failures += 1
    }
}

exit(failures == 0 ? 0 : 1)
