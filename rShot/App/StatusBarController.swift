//
//  StatusBarController.swift
//  rShot
//
//  自管理菜单栏图标（NSStatusItem + autosaveName）。
//  替代 SwiftUI MenuBarExtra：后者不设置 autosaveName，
//  系统设置的"菜单栏项目"管理（显示/移除/位置）无法与其关联 → 状态不同步。
//
//  菜单弹出用「手动 activate + popUp」：accessory app（LSUIElement）在未激活状态下，
//  系统默认的 status item 菜单弹出存在点击无响应的回归；手动激活后弹出门可靠。
//

import AppKit

final class StatusBarController: NSObject {
    static let shared = StatusBarController()
    private var statusItem: NSStatusItem?
    private var menu: NSMenu?
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
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseDown])
        }
        // 注意：不设置 item.menu —— 设置后系统拦截点击走默认弹出（accessory app 未激活时
        // 该路径有失效回归），改由 statusItemClicked 手动 activate + popUp
        menu = buildMenu()
        statusItem = item
        NSLog("[rShot] StatusBarController installed, menu items = \(menu?.items.count ?? -1)")
    }

    /// 点击图标：激活 app 后手动弹出菜单
    @objc private func statusItemClicked() {
        NSLog("[rShot] status item clicked")
        guard let button = statusItem?.button, let menu else { return }
        button.highlight(true)
        NSApp.activate(ignoringOtherApps: true)
        menu.popUp(positioning: nil, at: .zero, in: button)
        button.highlight(false)
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
