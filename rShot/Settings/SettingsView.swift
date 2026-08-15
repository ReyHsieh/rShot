//
//  SettingsView.swift
//  rShot
//
//  设置窗口（对应 OD screen-settings.html）：通用 / 快捷键 / OCR 三个标签页
//

import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            GeneralTab().tabItem {
                Label("通用", systemImage: "gear")
            }.tag(0)

            ShortcutsTab().tabItem {
                Label("快捷键", systemImage: "keyboard")
            }.tag(1)

            OCRTab().tabItem {
                Label("OCR", systemImage: "text.viewfinder")
            }.tag(2)
        }
        .frame(width: 460, height: 340)
    }
}

// MARK: - 通用

struct GeneralTab: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("保存") {
                LabeledContent("默认保存路径") {
                    HStack {
                        Text(settings.saveFolderPath).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                        Button("选择…") { pickFolder() }
                    }
                }
                Picker("图片格式", selection: $settings.imageFormat) {
                    Text("PNG").tag("PNG")
                    Text("JPG").tag("JPG")
                }
            }
            Section("行为") {
                Toggle("截图后自动复制到剪贴板", isOn: $settings.autoCopy)
                Toggle("同时保存到默认路径", isOn: $settings.autoSaveToFolder)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            settings.saveFolderPath = url.path
        }
    }
}

// MARK: - 快捷键

struct ShortcutsTab: View {
    var body: some View {
        Form {
            Section("全局快捷键") {
                shortcutRow("区域截图", name: .regionCapture,
                            defaultShortcut: DefaultShortcuts.region)
                shortcutRow("全屏截图", name: .fullScreenCapture,
                            defaultShortcut: DefaultShortcuts.fullScreen)
            }
            Section {
                Text("点击右侧录入框，然后按下新组合键完成修改（需至少一个修饰键 ⌘/⌥/⌃/⇧，按 ⌫ 或点 × 清除）。快捷键全局生效，任何 App 前台都可触发。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func shortcutRow(_ title: String,
                             name: KeyboardShortcuts.Name,
                             defaultShortcut: KeyboardShortcuts.Shortcut) -> some View {
        LabeledContent(title) {
            HStack(spacing: 8) {
                KeyboardShortcuts.Recorder(for: name)
                    .frame(width: 130, alignment: .trailing)
                Button("恢复默认") {
                    KeyboardShortcuts.setShortcut(defaultShortcut, for: name)
                }
                .controlSize(.small)
            }
        }
    }
}

// MARK: - OCR

struct OCRTab: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("识别") {
                Picker("识别语言", selection: Binding(
                    get: { settings.ocrLanguage },
                    set: { settings.ocrLanguage = $0 }
                )) {
                    ForEach(OCRLanguage.allCases, id: \.self) { l in
                        Text(l.displayName).tag(l)
                    }
                }
                LabeledContent("引擎") {
                    Text("macOS Vision · 离线").foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
