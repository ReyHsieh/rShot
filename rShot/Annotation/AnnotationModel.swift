//
//  AnnotationModel.swift
//  rShot
//
//  标注对象数据模型 + 撤销栈
//  对应 PRD：A-01 编辑器、A-05 撤销/重做
//

import SwiftUI
import CoreGraphics

/// 单个标注对象（矩形 / 文本 / 数字标记 / 箭头 / 高亮 / 马赛克 / 自由绘制）
enum AnnotationKind: String, CaseIterable, Codable {
    case rect       // A-02 矩形框选
    case text       // A-03 文本
    case number     // A-04 数字标记
    case arrow      // A-06 箭头 (P1)
    case mosaic     // A-07 马赛克 (P1)
    case highlight  // A-08 高亮笔 (P1)
    case pen        // A-09 自由画笔 (P2)
}

/// 文本样式：透明 / 底框（设计系统文档 §5.2）
enum TextStyle: String, Codable { case transparent, boxed }

struct Annotation: Identifiable, Codable {
    let id: UUID
    var kind: AnnotationKind
    var frame: CGRect              // 在画布逻辑坐标系（左上原点）
    var colorHex: String           // 标注颜色
    var lineWidth: CGFloat
    var filled: Bool               // 矩形是否填充
    var text: String               // 文本/数字内容
    var textStyle: TextStyle       // 文本样式
    var textBgHex: String          // 底框色（boxed）
    var fontSize: CGFloat
    var points: [CGPoint]          // 自由绘制 / 箭头端点

    init(id: UUID = UUID(), kind: AnnotationKind, frame: CGRect,
         colorHex: String = "#FF3B30", lineWidth: CGFloat = 3,
         filled: Bool = false, text: String = "", textStyle: TextStyle = .transparent,
         textBgHex: String = "#FFCC00", fontSize: CGFloat = 16,
         points: [CGPoint] = []) {
        self.id = id; self.kind = kind; self.frame = frame
        self.colorHex = colorHex; self.lineWidth = lineWidth; self.filled = filled
        self.text = text; self.textStyle = textStyle; self.textBgHex = textBgHex
        self.fontSize = fontSize; self.points = points
    }
}

/// 撤销栈（快照式，上限 50）
final class UndoStack: ObservableObject {
    @Published private(set) var history: [[Annotation]] = []
    @Published private(set) var index: Int = -1
    private let limit = 50

    /// 提交一个新快照（深拷贝）
    func commit(_ items: [Annotation]) {
        let snapshot = items.map { $0 }
        // 截断 redo 分支
        if index < history.count - 1 {
            history = Array(history.prefix(index + 1))
        }
        history.append(snapshot)
        if history.count > limit {
            history.removeFirst()
        }
        index = history.count - 1
    }

    var canUndo: Bool { index > 0 }
    var canRedo: Bool { index < history.count - 1 }

    func undo() -> [Annotation]? {
        guard canUndo else { return nil }
        index -= 1
        return history[index].map { $0 }
    }

    func redo() -> [Annotation]? {
        guard canRedo else { return nil }
        index += 1
        return history[index].map { $0 }
    }
}

// MARK: - 颜色工具

extension Color {
    /// 从 hex 字符串初始化（#RRGGBB）
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

/// 标注调色板（设计系统文档 §2.3，固定 8 色）
enum Palette {
    static let colors: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759",
        "#007AFF", "#5856D6", "#1d1d1f", "#FFFFFF"
    ]
    static let swatches: [Color] = colors.map { Color(hex: $0) }
}
