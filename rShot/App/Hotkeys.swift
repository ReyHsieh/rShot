//
//  Hotkeys.swift
//  rShot
//
//  全局快捷键定义（KeyboardShortcuts 库）：
//  任何 App 前台都响应；可在设置 > 快捷键中自定义录入。
//

import KeyboardShortcuts

/// 默认快捷键常量（设置页「恢复默认」用）
enum DefaultShortcuts {
    static let region = KeyboardShortcuts.Shortcut(.a, modifiers: [.command, .shift])
    static let fullScreen = KeyboardShortcuts.Shortcut(.s, modifiers: [.command, .shift])
}

extension KeyboardShortcuts.Name {
    static let regionCapture = Self("regionCapture", default: DefaultShortcuts.region)
    static let fullScreenCapture = Self("fullScreenCapture", default: DefaultShortcuts.fullScreen)
}

/// 全局热键注册（App 启动时调用一次）
enum HotkeyRegistrar {
    static func registerAll() {
        KeyboardShortcuts.onKeyDown(for: .regionCapture) {
            AppState.shared.startRegionCapture()
        }
        KeyboardShortcuts.onKeyDown(for: .fullScreenCapture) {
            AppState.shared.startFullScreenCapture()
        }
    }
}
