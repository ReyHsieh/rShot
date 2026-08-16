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

        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
                        styleMask: [.titled, .closable, .miniaturizable],
                        backing: .buffered, defer: false)
        p.title = "rShot 设置"
        p.isFloatingPanel = false
        p.isReleasedWhenClosed = false
        p.level = .floating
        p.contentView = NSHostingView(rootView:
            SettingsView().environmentObject(AppState.shared))
        p.center()
        panel = p
        resizeToFit()   // 首次按内容定高
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 窗口高度贴合当前 tab 内容自然高度（宽固定 460）：不滚动、不留白
    func resizeToFit() {
        guard let p = panel,
              let hosting = p.contentView as? NSHostingView<SettingsView> else { return }
        hosting.frame.size.width = 460
        hosting.layoutSubtreeIfNeeded()
        let fit = hosting.fittingSize
        let height = min(max(fit.height + 8, 320), 700)   // +8 布局余量
        NSLog("[rShot] settings fit=\(fit.height) → window=\(height)")
        p.setContentSize(NSSize(width: 460, height: height))
    }
}
