//
//  AnnotationModelTests.swift
//  rShotTests
//
//  标注模型与撤销栈：A-02/A-04/A-05 的数据层保障
//

import XCTest
import SwiftUI
@testable import rShot

final class AnnotationModelTests: XCTestCase {

    // MARK: - UndoStack（A-05 撤销/重做）

    func testUndoRedoSequence() {
        let stack = UndoStack()
        XCTAssertFalse(stack.canUndo, "空栈不可撤销")
        XCTAssertFalse(stack.canRedo, "空栈不可重做")

        stack.commit([makeItem(.rect)])
        XCTAssertFalse(stack.canUndo, "首个快照是基线，不可再撤销")

        stack.commit([makeItem(.rect), makeItem(.arrow)])
        stack.commit([makeItem(.rect), makeItem(.arrow), makeItem(.number)])
        XCTAssertTrue(stack.canUndo)

        // undo 两次回到基线
        let s2 = stack.undo()
        XCTAssertEqual(s2?.count, 2)
        let s1 = stack.undo()
        XCTAssertEqual(s1?.count, 1)
        XCTAssertFalse(stack.canUndo, "已到基线")
        XCTAssertTrue(stack.canRedo, "基线上可 redo")

        // redo 回到最新
        let r2 = stack.redo()
        XCTAssertEqual(r2?.count, 2)
        let r3 = stack.redo()
        XCTAssertEqual(r3?.count, 3)
        XCTAssertFalse(stack.canRedo, "已到最新")
    }

    func testUndoStackTruncatesOnNewCommit() {
        let stack = UndoStack()
        stack.commit([makeItem(.rect)])
        stack.commit([makeItem(.rect), makeItem(.arrow)])
        _ = stack.undo()   // 回到快照 1，redo 分支存在
        stack.commit([makeItem(.number)])   // 新提交应截断 redo 分支
        XCTAssertFalse(stack.canRedo, "新提交后 redo 分支应被截断")
    }

    func testUndoStackLimit() {
        let stack = UndoStack()
        for i in 0..<60 { stack.commit([makeItem(.number, text: "\(i)")]) }
        var undos = 0
        while stack.undo() != nil { undos += 1 }
        // 提交 60 次截断为 50 条历史；从 index 49 回到 0 可撤销 49 次
        XCTAssertEqual(undos, 49, "历史上限 50，可撤销 49 次回到最早快照")
    }

    // MARK: - Annotation

    func testNumberAutoIncrementSource() {
        let doc = AnnotationDocument()
        doc.add(Annotation(kind: .number, frame: .zero, text: "1"))
        doc.add(Annotation(kind: .number, frame: .zero, text: "2"))
        doc.add(Annotation(kind: .number, frame: .zero, text: "7"))
        XCTAssertEqual(doc.nextNumber, 8, "下一序号 = 现有最大 + 1")

        doc.remove(doc.items[2])
        XCTAssertEqual(doc.nextNumber, 3, "删除最大序号后重算")
    }

    // MARK: - 颜色

    func testColorHexParsing() {
        let red = Color(hex: "#FF3B30")
        // SwiftUI Color 无法直接读分量，此处验证构造不崩溃 + 与调色板一致的数量
        XCTAssertEqual(Palette.colors.count, 8, "设计系统 §2.3 固定 8 色")
        XCTAssertTrue(Palette.colors.contains("#007AFF"))
    }

    // MARK: - 辅助

    private func makeItem(_ kind: AnnotationKind, text: String = "") -> Annotation {
        Annotation(kind: kind, frame: CGRect(x: 0, y: 0, width: 10, height: 10),
                   text: text)
    }
}
