//
//  ToastCenter.swift
//  rShot
//
//  完成反馈 toast：屏幕底部居中毛玻璃胶囊，2 秒自动消失。
//  对应 OD screen-toast.html。AppState.flashToast 调用此处展示。
//

import SwiftUI
import AppKit

final class ToastCenter {
    static let shared = ToastCenter()
    private var panel: NSPanel?
    private var hideTask: DispatchWorkItem?

    private init() {}

    func show(_ text: String) {
        DispatchQueue.main.async { self.present(text) }
    }

    private func present(_ text: String) {
        hideTask?.cancel()

        let hosting = NSHostingView(rootView: ToastView(text: text))
        let size = hosting.fittingSize
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let panelFrame = NSRect(x: screenFrame.midX - size.width / 2,
                                 y: screenFrame.minY + 48,
                                 width: size.width, height: size.height)

        let p: NSPanel
        if let existing = panel {
            p = existing
            p.contentView = hosting
        } else {
            p = NSPanel(contentRect: panelFrame,
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
            p.level = .statusBar
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = true
            p.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
            panel = p
        }
        p.setFrame(panelFrame, display: true)
        p.orderFrontRegardless()

        let task = DispatchWorkItem { [weak self] in
            self?.panel?.orderOut(nil)
        }
        hideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: task)
    }
}

struct ToastView: View {
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(text)
                .font(.system(size: 13))
                .lineLimit(1)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(Capsule().fill(.regularMaterial))
        .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
        .padding(6)  // 留出阴影空间
    }
}
