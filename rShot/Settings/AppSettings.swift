//
//  AppSettings.swift
//  rShot
//
//  UserDefaults 持久化设置
//  对应 PRD：C-03 默认路径、C-04 格式 (P1)、C-05 OCR 语言 (P1)、C-06 自动复制 (P1)
//

import Foundation
import SwiftUI
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("saveFolderPath") var saveFolderPath: String = "~/Pictures/rShot"
    @AppStorage("imageFormat") var imageFormat: String = "PNG"
    @AppStorage("autoCopy") var autoCopy: Bool = true
    @AppStorage("autoSaveToFolder") var autoSaveToFolder: Bool = false
    @AppStorage("ocrLanguage") var ocrLanguageRaw: String = OCRLanguage.zhAndEn.rawValue
    @AppStorage("showInDock") var showInDock: Bool = false

    var ocrLanguage: OCRLanguage {
        get { OCRLanguage(rawValue: ocrLanguageRaw) ?? .zhAndEn }
        set {
            ocrLanguageRaw = newValue.rawValue
            OCRService.shared.language = newValue
        }
    }

    private init() {
        OCRService.shared.language = ocrLanguage
    }
}
