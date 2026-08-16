//
//  SettingsWindowController.swift
//  rShot
//
//  设置窗口（自建 NSWindow）。
//  弃用 SwiftUI Settings scene + showSettingsWindow: selector：
//  LSUIElement app 无主菜单，selector 走 responder chain 找不到接收者 → 打不开。
//

import SwiftUI
import AppKit

final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var panel: NSPanel?

    private init() {}

    func show() {
        if let p = panel, p.isVisible {
            p.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 460, height: 400),
                        styleMask: [.titled, .closable, .miniaturizable],
                        backing: .buffered, defer: false)
        p.title = "rShot 设置"
        p.isFloatingPanel = false
        p.isReleasedWhenClosed = false
        p.level = .floating
        p.contentView = NSHostingView(rootView:
            SettingsView().environmentObject(AppState.shared))
        p.center()
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel = p
    }
}
