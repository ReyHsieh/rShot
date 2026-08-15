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
        // 菜单栏常驻图标 + 下拉菜单（对应 OD screen-menubar.html）
        // 图标：取景框相机（camera.viewfinder），现代且贴合"框选截图"语义
        MenuBarExtra("rShot", systemImage: "camera.viewfinder") {
            MenuContentView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.menu)

        // 设置窗口（对应 OD screen-settings.html）
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

/// AppDelegate：注册全局热键（不手动改 activation policy —— LSUIElement 已处理，
/// SwiftUI App lifecycle 下手动 setActivationPolicy 会与 Scene 初始化死锁）
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        HotkeyRegistrar.registerAll()
        NSLog("[rShot] applicationDidFinishLaunching — app launched OK")
    }
}

/// 菜单栏下拉菜单内容（区域截图 / 全屏截图 / OCR 截图 / 设置 / 退出）
struct MenuContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("区域截图") {
            appState.startRegionCapture()
        }.keyboardShortcut("a", modifiers: [.command, .shift])

        Button("全屏截图") {
            appState.startFullScreenCapture()
        }.keyboardShortcut("s", modifiers: [.command, .shift])

        Divider()

        Button("设置…") {
            openSettings()
        }.keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("退出 rShot") {
            NSApplication.shared.terminate(nil)
        }.keyboardShortcut("q", modifiers: .command)
    }
}
