//
//  rShotApp.swift
//  rShot — macOS 截图工具
//
//  菜单栏常驻 + 区域/全屏截图 + 标注 + OCR
//

import SwiftUI

@main
struct rShotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        // 菜单栏图标由 StatusBarController（AppKit NSStatusItem + autosaveName）管理，
        // 不用 SwiftUI MenuBarExtra：后者导致系统"菜单栏项目"设置与其状态不同步。
        // 设置窗口由 SettingsWindowController 自建 NSWindow 管理
        //（Settings scene + selector 在 LSUIElement app 下打不开）。
        Settings { SettingsView() }
    }
}

/// AppDelegate：注册全局热键 + 菜单栏图标 + Dock 策略
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        HotkeyRegistrar.registerAll()
        StatusBarController.shared.install()
        // 启动期不立即 setActivationPolicy（会与 Scene 初始化死锁）；
        // 用户开启"Dock 显示"时延迟到下一 runloop 再切换
        if AppSettings.shared.showInDock {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                NSApp.setActivationPolicy(.regular)
            }
        }
        NSLog("[rShot] applicationDidFinishLaunching — app launched OK")
    }
}
