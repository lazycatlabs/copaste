import SwiftUI

enum AnnotationTool: String, CaseIterable, Identifiable {
    case pen, highlighter, rectangle, arrow, text

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .pen: "pencil.tip"
        case .highlighter: "highlighter"
        case .rectangle: "rectangle"
        case .arrow: "arrow.up.right"
        case .text: "textformat"
        }
    }

    var title: String {
        switch self {
        case .pen: L(.toolPen)
        case .highlighter: L(.toolHighlighter)
        case .rectangle: L(.toolRectangle)
        case .arrow: L(.toolArrow)
        case .text: L(.toolText)
        }
    }
}

/// One stroke or shape on an image. Points are shares of the image's size (0…1), so a mark is drawn the same
/// on screen and in the full-size saved image.
struct AnnotationMark: Identifiable {
    let id = UUID()
    var tool: AnnotationTool
    var color: Color
    /// Line width as a share of the image's width.
    var width: CGFloat
    var points: [CGPoint]
    /// What a text mark says; its top-left corner is the first point.
    var text = ""

    /// A text mark's font size on an image (or canvas) of this size.
    func fontSize(in size: CGSize) -> CGFloat {
        width * size.width * Metrics.Annotate.textScale
    }

    func draw(in context: GraphicsContext, size: CGSize) {
        let points = points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        guard let first = points.first, let last = points.last else { return }
        if tool == .text {
            let label = Text(text).font(.system(size: fontSize(in: size), weight: .semibold)).foregroundStyle(color)
            return context.draw(label, at: first, anchor: .topLeading)
        }
        let lineWidth = width * size.width * (tool == .highlighter ? Metrics.Annotate.highlighterScale : 1)
        var path = Path()
        switch tool {
        case .pen, .highlighter:
            path.addLines(points)
        case .rectangle:
            path.addRect(CGRect(x: min(first.x, last.x), y: min(first.y, last.y),
                                width: abs(last.x - first.x), height: abs(last.y - first.y)))
        case .text:
            return
        case .arrow:
            path.move(to: first)
            path.addLine(to: last)
            let angle = atan2(last.y - first.y, last.x - first.x)
            let head = lineWidth * Metrics.Annotate.arrowHeadLength
            for side in [-1.0, 1.0] {
                let wing = angle + .pi - side * Metrics.Annotate.arrowHeadAngle
                path.move(to: last)
                path.addLine(to: CGPoint(x: last.x + head * cos(wing), y: last.y + head * sin(wing)))
            }
        }
        let shading = tool == .highlighter ? color.opacity(Opacity.highlighter) : color
        context.stroke(path, with: .color(shading), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
    }
}
