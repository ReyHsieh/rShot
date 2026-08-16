//
//  ClipboardService.swift  +  FileService
//  rShot
//
//  复制到剪贴板 (F-01) + 保存到固定路径 (F-02) + 另存为 (F-04, P1)
//

import AppKit

final class ClipboardService {
    static let shared = ClipboardService()
    private init() {}

    func copyImage(_ image: NSImage) {
        let tiff = image.tiffRepresentation
        let png = image.pngRepresentation()
        copyPrepared(tiff: tiff, png: png)
    }

    /// 编码已在后台完成的数据直接写剪贴板（须在主线程调用）
    func copyPrepared(tiff: Data?, png: Data?) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if let tiff { pb.setData(tiff, forType: .tiff) }
        if let png { pb.setData(png, forType: .png) }
    }

    func copyText(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}

final class FileService {
    static let shared = FileService()
    private init() {}

    var autoCopyOnlyClipboard: Bool { !AppSettings.shared.autoSaveToFolder }
    var lastSavedPath: String?

    /// 无条件保存到设置中的固定路径（编辑器「保存」按钮）。返回 (成功, 路径)。
    /// 文件名带扩展名，格式跟随设置的 PNG/JPG 选项。
    func saveToDefaultPath(_ image: NSImage) -> (Bool, String) {
        let dir = URL(fileURLWithPath: (AppSettings.shared.saveFolderPath as NSString).expandingTildeInPath)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ext = AppSettings.shared.imageFormat.lowercased() == "jpg" ? "jpg" : "png"
        let fileURL = dir.appendingPathComponent(filename() + "." + ext)
        let ok = write(image, to: fileURL)
        if ok { lastSavedPath = fileURL.path }
        return (ok, fileURL.path)
    }

    /// 按设置自动保存（完成截图时若开启"同时保存到默认路径"）
    func saveIfConfigured(_ image: NSImage) {
        guard AppSettings.shared.autoSaveToFolder else { return }
        _ = saveToDefaultPath(image)
    }

    /// 另存为…（系统保存对话框，F-04）
    func saveAs(_ image: NSImage, completion: @escaping (Bool, String) -> Void) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png, .jpeg]
        panel.nameFieldStringValue = filename()
        panel.begin { resp in
            guard resp == .OK, let url = panel.url else {
                completion(false, ""); return
            }
            let ok = self.write(image, to: url)
            if ok { self.lastSavedPath = url.path }
            completion(ok, url.path)
        }
    }

    private func write(_ image: NSImage, to url: URL) -> Bool {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return false }
        let data: Data?
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg":
            data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        default:
            data = rep.representation(using: .png, properties: [:])
        }
        guard let d = data else { return false }
        return FileManager.default.createFile(atPath: url.path, contents: d)
    }

    private func filename() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmmss"
        return "rShot_\(f.string(from: Date()))"
    }
}

extension NSImage {
    func pngRepresentation() -> Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
