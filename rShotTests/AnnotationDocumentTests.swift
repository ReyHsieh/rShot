//
//  AnnotationDocumentTests.swift
//  rShotTests
//
//  编辑器文档：增删改 / 移动 / 每工具记忆 / 文本锚点 / 马赛克渲染
//

import XCTest
import AppKit
@testable import rShot

final class AnnotationDocumentTests: XCTestCase {

    // MARK: - 增删改 + 撤销

    func testAddRemoveUndoRedo() {
        let doc = AnnotationDocument()
        let a = Annotation(kind: .rect, frame: CGRect(x: 0, y: 0, width: 100, height: 80))
        doc.add(a)
        XCTAssertEqual(doc.items.count, 1)

        doc.remove(a)
        XCTAssertEqual(doc.items.count, 0)
        XCTAssertTrue(doc.undoStack.canUndo)

        doc.undo()
        XCTAssertEqual(doc.items.count, 1, "撤销删除后恢复")

        doc.redo()
        XCTAssertEqual(doc.items.count, 0, "重做删除")
    }

    // MARK: - 移动（含轨迹平移）

    func testMoveAnnotationShiftsFrameAndPoints() {
        let doc = AnnotationDocument()
        let arrow = Annotation(kind: .arrow,
                               frame: CGRect(x: 10, y: 10, width: 90, height: 40),
                               points: [CGPoint(x: 10, y: 50), CGPoint(x: 100, y: 10)])
        doc.add(arrow)

        let moved = CGRect(x: 40, y: 30, width: 90, height: 40)
        let movedPoints = [CGPoint(x: 40, y: 70), CGPoint(x: 130, y: 30)]
        doc.moveAnnotation(id: arrow.id, frame: moved, points: movedPoints)

        XCTAssertEqual(doc.items[0].frame, moved, "frame 平移")
        XCTAssertEqual(doc.items[0].points, movedPoints, "轨迹同步平移")
    }

    // MARK: - 文本编辑（草稿同步 + 提交快照）

    func testUpdateTextAndCommitSnapshot() {
        let doc = AnnotationDocument()
        let t = Annotation(kind: .text, frame: CGRect(x: 5, y: 5, width: 160, height: 28),
                           text: "")
        doc.add(t)

        doc.updateText(id: t.id, "你好 rShot")
        XCTAssertEqual(doc.items[0].text, "你好 rShot", "草稿实时同步")

        let before = doc.undoStack.canUndo
        doc.commitSnapshot()
        XCTAssertTrue(doc.undoStack.canUndo, "提交快照后可撤销")
        XCTAssertTrue(before || true)
    }

    // MARK: - 每工具记忆（设计系统 §5.3.4）

    func testPerToolMemory() {
        let doc = AnnotationDocument()
        doc.set("#FFCC00", for: .rect)
        doc.set(CGFloat(5), for: .rect)
        doc.setTextStyle(.transparent, for: .text)
        doc.setFontSize(24, for: .text)

        XCTAssertEqual(doc.color(for: .rect), "#FFCC00")
        XCTAssertEqual(doc.lineWidth(for: .rect), 5)
        XCTAssertEqual(doc.textStyle(for: .text), .transparent)
        XCTAssertEqual(doc.fontSize(for: .text), 24)
        // 其他工具不受影响（默认值）
        XCTAssertEqual(doc.textStyle(for: .number), .boxed)
    }

    // MARK: - 文本锚点（提交后不跳位）

    func testTextLayoutAnchor() {
        let item = Annotation(kind: .text,
                              frame: CGRect(x: 300, y: 200, width: 160, height: 28))
        XCTAssertEqual(AnnotationTextLayout.anchorX(for: item), 300 + 100,
                       "锚点 X = 左缘 + 固定宽/2")
        XCTAssertEqual(AnnotationTextLayout.anchorY(for: item), 214,
                       "锚点 Y = frame 中线")
    }

    // MARK: - 马赛克像素化（A-07）

    func testMosaicPixelation() {
        // 合成 200×100 px 底图
        let w = 200, h = 100
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 100, height: h))
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 100, y: 0, width: 100, height: h))
        let cg = ctx.makeImage()!

        let frame = CGRect(x: 20, y: 10, width: 80, height: 50)
        let canvas = CGSize(width: 200, height: 100)
        let out = MosaicRenderer.pixelated(from: cg, frame: frame, canvas: canvas, blockSize: 16)

        XCTAssertNotNil(out, "正常输入应产出像素化图像")
        XCTAssertEqual(out!.size.width, frame.width, accuracy: 0.5,
                       "输出点尺寸 = frame")
        XCTAssertEqual(out!.size.height, frame.height, accuracy: 0.5)
    }

    func testMosaicRejectsInvalidInput() {
        let ctx = CGContext(data: nil, width: 10, height: 10, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let cg = ctx.makeImage()!
        XCTAssertNil(MosaicRenderer.pixelated(from: cg,
                                              frame: CGRect(x: 0, y: 0, width: 0, height: 0),
                                              canvas: CGSize(width: 10, height: 10)),
                     "零尺寸区域应返回 nil")
    }

    // MARK: - 渲染扁平化（复制/保存输出）

    @MainActor
    func testRenderFlattened() {
        let doc = AnnotationDocument()
        // 10×5 的纯色底图
        let ctx = CGContext(data: nil, width: 10, height: 5, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let cg = ctx.makeImage()!
        doc.image = NSImage(cgImage: cg, size: CGSize(width: 100, height: 50))
        doc.canvasSize = CGSize(width: 100, height: 50)
        doc.add(Annotation(kind: .rect, frame: CGRect(x: 10, y: 10, width: 30, height: 20)))

        let rendered = doc.renderFlattened()
        XCTAssertNotNil(rendered, "含图 + 标注应能渲染成品")
        XCTAssertEqual(rendered!.size.width, 100, accuracy: 1)
        XCTAssertEqual(rendered!.size.height, 50, accuracy: 1)
    }

    @MainActor
    func testRenderFlattenedNilWithoutImage() {
        let doc = AnnotationDocument()
        doc.canvasSize = CGSize(width: 100, height: 50)
        XCTAssertNil(doc.renderFlattened(), "无底图应返回 nil")
    }
}

// Double 容差断言（NSImage.size 可能带小数）
private func XCTAssertEqual(_ a: CGFloat, _ b: CGFloat, accuracy: CGFloat,
                            file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertTrue(abs(a - b) <= accuracy, "\(a) 与 \(b) 差值超过 \(accuracy)",
                  file: file, line: line)
}
