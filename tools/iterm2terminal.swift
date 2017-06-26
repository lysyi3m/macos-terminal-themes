#!/usr/bin/xcrun swift

import AppKit

class ThemeConvertor {
    enum ThemeConvertorError: Error {
        case NoArguments, UnableToLoadITermFile(URL)
    }
    
    private let iTermFiles: [String]
    
    private let iTermColor2TerminalColorMap = [
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
        "Bold Color": "BoldTextColor",
        "Cursor Color": "CursorColor",
    ]
    
    required init(iTermFiles: [String]) throws {
        if iTermFiles.isEmpty {
            throw ThemeConvertorError.NoArguments
        }
        self.iTermFiles = iTermFiles
    }
    
    func run() {
        for iTermFile in iTermFiles {
            let iTermFileURL = URL(fileURLWithPath: iTermFile).absoluteURL
            let folder = iTermFileURL.deletingLastPathComponent()
            let schemeName = iTermFileURL.deletingPathExtension().lastPathComponent
            let terminalFileURL = folder.appendingPathComponent("\(schemeName).terminal")
            do {
              try convert(scheme: schemeName, fromITermFileAtURL: iTermFileURL, toTerminalFileAtURL: terminalFileURL)
            }
            catch ThemeConvertorError.UnableToLoadITermFile(let iTermFileURL) {
                print("Error: Unable to load \(iTermFileURL)")
            }
            catch let error as NSError {
                print("Error: \(error.description)")
            }
        }
    }
    
    private func convert(scheme: String, fromITermFileAtURL src: URL, toTerminalFileAtURL dest: URL) throws {
        guard let iTermScheme = NSDictionary(contentsOf: src) else {
            throw ThemeConvertorError.UnableToLoadITermFile(src)
        }
        
        print("Converting \(src) -> \(dest)")
        
        var terminalScheme: [String: Any] = [
            "name" : scheme,
            "type" : "Window Settings",
            "ProfileCurrentVersion" : 2.04,
            "columnCount": 90,
            "rowCount": 50,
        ]
        
      if let font = archivedFont(withName: "PragmataPro", size: 14) {
            terminalScheme["Font"] = font
        }
        
        for (iTermColorKey, iTermColorDict) in iTermScheme {
            if let iTermColorKey = iTermColorKey as? String,
                let terminalColorKey = iTermColor2TerminalColorMap[iTermColorKey],
                let iTermColorDict = iTermColorDict as? NSDictionary,
                let r = (iTermColorDict["Red Component"] as AnyObject?)?.floatValue,
                let g = (iTermColorDict["Green Component"] as AnyObject?)?.floatValue,
                let b = (iTermColorDict["Blue Component"] as AnyObject?)?.floatValue {
                
                    let color = NSColor(calibratedRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1)
                    let colorData = NSKeyedArchiver.archivedData(withRootObject: color)
                    terminalScheme[terminalColorKey] = colorData
            }
        }
      NSDictionary(dictionary: terminalScheme).write(to: dest, atomically: true)
    }
    
    private func archivedFont(withName name: String, size: CGFloat) -> Data? {
        guard let font = NSFont(name: name, size: size) else {
            return nil
        }
        return NSKeyedArchiver.archivedData(withRootObject: font)
    }
}


do {
    let iTermFiles = [String](CommandLine.arguments.dropFirst())
    try ThemeConvertor(iTermFiles: iTermFiles).run()
}
catch ThemeConvertor.ThemeConvertorError.NoArguments {
    print("Error: no arguments provided")
    print("Usage: iTermColorsToTerminalColors FILE.ITermColors [...]")
}
