//
//  StatusBarController.swift
//  rShot
//
//  自管理菜单栏图标（NSStatusItem + autosaveName）。
//  替代 SwiftUI MenuBarExtra：后者不设置 autosaveName，
//  系统设置的"菜单栏项目"管理（显示/移除/位置）无法与其关联 → 状态不同步。
//
//  菜单走系统默认弹出路径（item.menu）：渲染最可靠。
//  之前用手动 menu.popUp 规避"未激活时点击无响应"，但该 API 存在
//  首帧渲染不完整（需移动鼠标才显示）的顽固问题，多机复现，弃用。
//  激活问题改由 menuWillOpen 里 NSApp.activate 兜底。
//

import AppKit

final class StatusBarController: NSObject, NSMenuDelegate {
    static let shared = StatusBarController()
    private var statusItem: NSStatusItem?
    /// NSMenuItem 不支持闭包，用轻量 target 对象承载动作
    private var actions: [MenuItemAction] = []

    private override init() { super.init() }

    func install() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // autosaveName：系统据此持久化位置与显示状态（修复系统设置不同步）
        item.autosaveName = "rShot"
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder",
                                    accessibilityDescription: "rShot")
            button.image?.isTemplate = true   // 自动适配明暗菜单栏
        }
        let menu = buildMenu()
        menu.delegate = self
        item.menu = menu   // 系统默认弹出路径（不设自定义 action，避免拦截）
        statusItem = item
        NSLog("[rShot] StatusBarController installed (system menu path), items = \(menu.items.count)")
    }

    // MARK: - NSMenuDelegate

    /// 菜单即将打开：确保 app 已激活（accessory app 未激活时系统弹出的兜底）
    func menuWillOpen(_ menu: NSMenu) {
        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func buildMenu() -> NSMenu {
        actions.removeAll()
        let menu = NSMenu()

        menu.add(menuItem("区域截图", key: "a", mods: [.command, .shift]) {
            AppState.shared.startRegionCapture()
        })
        menu.add(menuItem("全屏截图", key: "s", mods: [.command, .shift]) {
            AppState.shared.startFullScreenCapture()
        })
        menu.addItem(.separator())
        menu.add(menuItem("设置…", key: ",", mods: [.command]) {
            AppState.shared.openSettings()
        })
        menu.addItem(.separator())
        menu.add(menuItem("退出 rShot", key: "q", mods: [.command]) {
            NSApp.terminate(nil)
        })
        return menu
    }

    private func menuItem(_ title: String,
                          key: String,
                          mods: NSEvent.ModifierFlags,
                          handler: @escaping () -> Void) -> NSMenuItem {
        let action = MenuItemAction(handler)
        actions.append(action)
        let mi = NSMenuItem(title: title,
                            action: #selector(MenuItemAction.fire),
                            keyEquivalent: key)
        mi.keyEquivalentModifierMask = mods
        mi.target = action
        return mi
    }
}

/// NSMenuItem 动作承载（闭包转 target/selector）
private final class MenuItemAction: NSObject {
    private let handler: () -> Void
    init(_ handler: @escaping () -> Void) { self.handler = handler }
    @objc func fire() { handler() }
}

private extension NSMenu {
    func add(_ item: NSMenuItem) { addItem(item) }
}
