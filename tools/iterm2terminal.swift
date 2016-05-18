#!/usr/bin/xcrun swift

import AppKit

class ThemeConvertor {
    enum Error: ErrorType {
        case NoArguments, UnableToLoadITermFile(NSURL)
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
            throw Error.NoArguments
        }
        self.iTermFiles = iTermFiles
    }
    
    func run() {
        for iTermFile in iTermFiles {
            let iTermFileURL = NSURL(fileURLWithPath: iTermFile).absoluteURL
            let folder = iTermFileURL.URLByDeletingLastPathComponent!
            let schemeName = iTermFileURL.URLByDeletingPathExtension!.lastPathComponent!
            let terminalFileURL = folder.URLByAppendingPathComponent("\(schemeName).terminal")
            do {
                try convertScheme(schemeName, fromITermFileAtURL: iTermFileURL, toTerminalFileAtURL: terminalFileURL)
            }
            catch Error.UnableToLoadITermFile(let iTermFileURL) {
                print("Error: Unable to load \(iTermFileURL)")
            }
            catch let error as NSError {
                print("Error: \(error.description)")
            }
        }
    }
    
    private func convertScheme(scheme: String, fromITermFileAtURL src: NSURL, toTerminalFileAtURL dest: NSURL) throws {
        guard let iTermScheme = NSDictionary(contentsOfURL: src) else {
            throw Error.UnableToLoadITermFile(src)
        }
        
        print("Converting \(src) -> \(dest)")
        
        var terminalScheme: [String: AnyObject] = [
            "name" : scheme,
            "type" : "Window Settings",
            "ProfileCurrentVersion" : 2.04,
            "columnCount": 90,
            "rowCount": 50,
        ]
        
        if let font = archivedFontWithName("PragmataPro", size: 14) {
            terminalScheme["Font"] = font
        }
        
        for (iTermColorKey, iTermColorDict) in iTermScheme {
            if let iTermColorKey = iTermColorKey as? String,
                let terminalColorKey = iTermColor2TerminalColorMap[iTermColorKey],
                let iTermColorDict = iTermColorDict as? NSDictionary,
                let r = iTermColorDict["Red Component"]?.floatValue,
                let g = iTermColorDict["Green Component"]?.floatValue,
                let b = iTermColorDict["Blue Component"]?.floatValue {
                
                    let color = NSColor(calibratedRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1)
                    let colorData = NSKeyedArchiver.archivedDataWithRootObject(color)
                    terminalScheme[terminalColorKey] = colorData
            }
        }
        NSDictionary(dictionary: terminalScheme).writeToURL(dest, atomically: true)
    }
    
    private func archivedFontWithName(name: String, size: CGFloat) -> NSData? {
        guard let font = NSFont(name: name, size: size) else {
            return nil
        }
        return NSKeyedArchiver.archivedDataWithRootObject(font)
    }
}


do {
    let iTermFiles = [String](Process.arguments.dropFirst())
    try ThemeConvertor(iTermFiles: iTermFiles).run()
}
catch ThemeConvertor.Error.NoArguments {
    print("Error: no arguments provided")
    print("Usage: iTermColorsToTerminalColors FILE.ITermColors [...]")
}
