//
//  OCRPanelController.swift
//  rShot
//
//  OCR 结果面板（AppKit NSPanel）。
//  旧的 openWindowWithID: selector 方式在 SwiftUI App lifecycle 下无效，改用主动 NSPanel。
//

import SwiftUI
import AppKit

final class OCRPanelController {
    static let shared = OCRPanelController()
    private var panel: NSPanel?

    private init() {}

    func show() {
        if let p = panel, p.isVisible {
            p.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 460, height: 420),
                        styleMask: [.titled, .closable, .miniaturizable, .resizable],
                        backing: .buffered, defer: false)
        p.title = "rShot OCR"
        p.isFloatingPanel = true
        p.level = .floating
        p.isReleasedWhenClosed = false
        p.contentView = NSHostingView(rootView:
            OCRResultView().environmentObject(AppState.shared))
        p.center()
        p.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        panel = p
    }

    func close() {
        panel?.orderOut(nil)
    }
}
