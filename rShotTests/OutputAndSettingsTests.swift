//
//  OutputAndSettingsTests.swift
//  rShotTests
//
//  保存路径/格式（F-02/C-04）、OCR 结果模型、快捷键默认值
//

import XCTest
import AppKit
@testable import rShot

final class OutputAndSettingsTests: XCTestCase {

    private var tmpDir: String!

    override func setUp() {
        super.setUp()
        tmpDir = NSTemporaryDirectory() + "/rShotTests-\(UUID().uuidString)"
        UserDefaults.standard.set(tmpDir, forKey: "saveFolderPath")
        try? FileManager.default.createDirectory(atPath: tmpDir,
                                                 withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let d = tmpDir { try? FileManager.default.removeItem(atPath: d) }
        super.tearDown()
    }

    private func solidImage(_ w: Int, _ h: Int) -> NSImage {
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        let cg = ctx.makeImage()!
        return NSImage(cgImage: cg, size: NSSize(width: w, height: h))
    }

    // MARK: - 固定路径保存 + 扩展名（F-02 / C-04）

    func testSaveToDefaultPathPNG() throws {
        UserDefaults.standard.set("PNG", forKey: "imageFormat")
        let (ok, path) = FileService.shared.saveToDefaultPath(solidImage(20, 10))
        XCTAssertTrue(ok, "保存应成功")
        XCTAssertTrue(path.hasSuffix(".png"), "PNG 格式文件应有 .png 扩展名：\(path)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: path), "文件应真实落盘")
    }

    func testSaveToDefaultPathJPG() throws {
        UserDefaults.standard.set("JPG", forKey: "imageFormat")
        let (ok, path) = FileService.shared.saveToDefaultPath(solidImage(20, 10))
        XCTAssertTrue(ok)
        XCTAssertTrue(path.hasSuffix(".jpg"), "JPG 格式文件应有 .jpg 扩展名：\(path)")
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
    }

    func testSaveIfConfiguredRespectsToggle() {
        UserDefaults.standard.set("PNG", forKey: "imageFormat")
        UserDefaults.standard.set(false, forKey: "autoSaveToFolder")
        let before = filesIn(tmpDir)
        FileService.shared.saveIfConfigured(solidImage(5, 5))
        XCTAssertEqual(filesIn(tmpDir), before, "开关关闭时不应写文件")

        UserDefaults.standard.set(true, forKey: "autoSaveToFolder")
        FileService.shared.saveIfConfigured(solidImage(5, 5))
        XCTAssertEqual(filesIn(tmpDir), before + 1, "开关开启时应写一个文件")
    }

    // MARK: - 剪贴板（F-01）

    func testCopyImageToPasteboard() throws {
        ClipboardService.shared.copyImage(solidImage(4, 4))
        let types = NSPasteboard.general.types ?? []
        XCTAssertTrue(types.contains(.png) || types.contains(.tiff),
                      "剪贴板应含图像类型")
        ClipboardService.shared.copyText("rShot 测试")
        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "rShot 测试")
    }

    // MARK: - OCR 结果模型（O-02）

    func testOCRResult() {
        let r = OCRResult(lines: ["第一行", "第二行"])
        XCTAssertEqual(r.fullText, "第一行\n第二行")
        XCTAssertEqual(r, OCRResult(lines: ["第一行", "第二行"]))
        XCTAssertNotEqual(r, OCRResult(lines: []))
    }

    // MARK: - OCR 语言显示名（O-04）

    func testOCRLanguageDisplayNames() {
        XCTAssertEqual(OCRLanguage.zhHans.displayName, "中文")
        XCTAssertEqual(OCRLanguage.en.displayName, "英文")
        XCTAssertEqual(OCRLanguage.zhAndEn.displayName, "中英")
    }

    // MARK: - 默认快捷键（C-02）

    func testDefaultShortcuts() {
        XCTAssertNotNil(DefaultShortcuts.region)
        XCTAssertNotNil(DefaultShortcuts.fullScreen)
    }

    // MARK: - 辅助

    private func filesIn(_ dir: String?) -> Int {
        guard let d = dir,
              let list = try? FileManager.default.contentsOfDirectory(atPath: d)
        else { return -1 }
        return list.filter { !$0.hasPrefix(".") }.count
    }
}
