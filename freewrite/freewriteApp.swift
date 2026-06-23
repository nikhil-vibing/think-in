//
//  freewriteApp.swift
//  freewrite
//
//  Created by thorfinn on 2/14/25.
//

import SwiftUI
import CoreText

@main
struct freewriteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("colorScheme") private var colorSchemeString: String = "light"

    init() {
        let latoFonts = [
            "Lato-Black", "Lato-BlackItalic", "Lato-Bold", "Lato-BoldItalic",
            "Lato-Italic", "Lato-Light", "Lato-LightItalic",
            "Lato-Regular", "Lato-Thin", "Lato-ThinItalic"
        ]
        for fontName in latoFonts {
            if let fontURL = Bundle.main.url(forResource: fontName, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .toolbar(.hidden, for: .windowToolbar)
                .preferredColorScheme(colorSchemeString == "dark" ? .dark : .light)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 600)
        .windowToolbarStyle(.unifiedCompact)
        .windowResizability(.contentSize)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first {
            if window.styleMask.contains(.fullScreen) {
                window.toggleFullScreen(nil)
            }
            window.center()
        }
    }
}
