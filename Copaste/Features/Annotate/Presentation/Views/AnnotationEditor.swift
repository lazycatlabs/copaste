import SwiftUI
import UniformTypeIdentifiers

/// Draw on an image (pen, highlighter, rectangle, arrow), then keep the result as a new clipboard entry.
struct AnnotationEditor: View {
    let image: PlatformImage
    /// Called with the annotated image as PNG, and its size in pixels.
    let onDone: (Data, Int, Int) -> Void
    let onCancel: () -> Void

    private static let palette: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .black, .white]

    @State private var marks: [AnnotationMark] = []
    @State private var current: AnnotationMark?
    @State private var tool = AnnotationTool.pen
    @State private var color = Color.red
    @State private var widthIndex = 1
    @State private var canvasSize = CGSize.zero

    var body: some View {
        VStack(spacing: 0) {
            toolbar.padding(Spacing.xl)
            Divider()
            canvas.padding(Spacing.page).frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            footer.padding(Spacing.xl)
        }
    }

    private var toolbar: some View {
        HStack(spacing: Spacing.xl) {
            Picker(L(.annotateTool), selection: $tool) {
                ForEach(AnnotationTool.allCases) { Label($0.title, systemImage: $0.symbolName).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            HStack(spacing: Spacing.sm) {
                ForEach(Self.palette, id: \.self) { swatch in
                    Circle().fill(swatch)
                        .overlay(Circle().strokeBorder(.primary.opacity(Opacity.border)))
                        .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: swatch == color ? Metrics.Annotate.selectedRing : 0)
                            .padding(-Metrics.Annotate.selectedRing * 2))
                        .frame(width: Metrics.Annotate.swatch, height: Metrics.Annotate.swatch)
                        .onTapGesture { color = swatch }
                        .accessibilityAddTraits(.isButton)
                }
            }
            Picker(L(.annotateWidth), selection: $widthIndex) {
                ForEach(Metrics.Annotate.widths.indices, id: \.self) { index in
                    Image(systemName: "circle.fill").imageScale([.small, .medium, .large][index]).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            Spacer(minLength: 0)
            Button(L(.actionUndo), systemImage: "arrow.uturn.backward") { _ = marks.popLast() }
                .disabled(marks.isEmpty)
                .keyboardShortcut("z")
            Button(L(.actionClear), systemImage: "trash") { marks.removeAll() }
                .disabled(marks.isEmpty)
        }
        .labelStyle(.iconOnly)
    }

    private var canvas: some View {
        ZStack {
            Image(platformImage: image).resizable()
            Canvas { context, size in
                for mark in marks + [current].compactMap({ $0 }) { mark.draw(in: context, size: size) }
            }
        }
        .aspectRatio(image.size, contentMode: .fit)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { canvasSize = $0 }
        .gesture(drawing)
        .accessibilityIdentifier("annotate.canvas")
    }

    private var drawing: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard canvasSize.width > 0, canvasSize.height > 0 else { return }
                let point = CGPoint(x: value.location.x / canvasSize.width, y: value.location.y / canvasSize.height)
                if current == nil {
                    current = AnnotationMark(tool: tool, color: color, width: Metrics.Annotate.widths[widthIndex], points: [point])
                } else if tool == .pen || tool == .highlighter {
                    current?.points.append(point)
                } else {
                    current?.points = [current?.points.first ?? point, point]
                }
            }
            .onEnded { _ in
                if let current { marks.append(current) }
                current = nil
            }
    }

    private var footer: some View {
        HStack {
            Button(L(.actionCancel), action: onCancel).keyboardShortcut(.cancelAction)
            Spacer()
            #if os(macOS)
            Button(L(.actionSaveToFile)) {
                if let (png, _, _) = render() { FileExporter.save(png, name: L(.annotatedFileName), type: .png) }
            }
            #endif
            Button(L(.annotateDone)) {
                if let (png, width, height) = render() { onDone(png, width, height) }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
        }
    }

    /// The image at full size with the marks drawn on it.
    private func render() -> (Data, Int, Int)? {
        let pixels = image.pixelSize
        let content = ZStack {
            Image(platformImage: image).resizable()
            Canvas { context, size in for mark in marks { mark.draw(in: context, size: size) } }
        }
        .frame(width: pixels.width, height: pixels.height)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        #if os(macOS)
        let output = renderer.nsImage
        #else
        let output = renderer.uiImage
        #endif
        guard let png = output?.pngRepresentation else { return nil }
        return (png, Int(pixels.width), Int(pixels.height))
    }
}
