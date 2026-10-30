import SwiftUI
import UniformTypeIdentifiers

/// Draw and write on an image (pen, highlighter, shapes, arrow, text), then keep the result as a new clipboard entry.
struct AnnotationEditor: View {
    let image: NSImage
    /// Called with the annotated image as PNG, and its size in pixels.
    let onDone: (Data, Int, Int) -> Void
    /// Called with the annotated image as PNG, to put it on the clipboard without keeping it as an entry.
    let onCopy: (Data) -> Void
    let onCancel: () -> Void

    private static let palette: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .black, .white]

    @State private var marks: [AnnotationMark] = []
    @State private var current: AnnotationMark?
    @State private var tool = AnnotationTool.pen
    @State private var color = Color.red
    @State private var width = Metrics.Annotate.defaultWidth
    @State private var filled = false
    @State private var canvasSize = CGSize.zero
    /// The text mark being typed, shown as a field on the canvas until it's committed.
    @State private var typing: AnnotationMark?
    @FocusState private var typingFocused: Bool

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
            .onChange(of: tool) { commitText() }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            if tool.isShape {
                Picker(L(.annotateShapeStyle), selection: $filled) {
                    Label(L(.annotateOutline), systemImage: "square").tag(false)
                    Label(L(.annotateFill), systemImage: "square.fill").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            HStack(spacing: Spacing.sm) {
                ForEach(Self.palette, id: \.self) { swatch in
                    Circle().fill(swatch)
                        .overlay(Circle().strokeBorder(.primary.opacity(Opacity.border)))
                        .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: swatch == color ? Metrics.Annotate.selectedRing : 0)
                            .padding(-Metrics.Annotate.selectedRing * 2))
                        .frame(width: Metrics.Annotate.swatch, height: Metrics.Annotate.swatch)
                        .onTapGesture {
                            color = swatch
                            typing?.color = swatch
                        }
                        .accessibilityAddTraits(.isButton)
                }
            }
            sizeControl
            Spacer(minLength: 0)
            Button(L(.actionUndo), systemImage: "arrow.uturn.backward") { _ = marks.popLast() }
                .disabled(marks.isEmpty)
                .keyboardShortcut(typing == nil ? KeyboardShortcut("z") : nil)
            Button(L(.actionClear), systemImage: "trash") { marks.removeAll() }
                .disabled(marks.isEmpty)
        }
        .labelStyle(.iconOnly)
    }

    /// A slider for the stroke size, next to a dot as wide as the stroke will be on the canvas.
    private var sizeControl: some View {
        HStack(spacing: Spacing.sm) {
            let sample = AnnotationMark(tool: tool, color: color, width: width, points: [])
            Circle().fill(color)
                .overlay(Circle().strokeBorder(.primary.opacity(Opacity.border)))
                .frame(width: min(max(sample.lineWidth(in: canvasSize), Metrics.Annotate.sizePreviewMin), Metrics.Annotate.sizePreviewMax))
                .frame(width: Metrics.Annotate.sizePreviewMax, height: Metrics.Annotate.sizePreviewMax)
            Slider(value: $width, in: Metrics.Annotate.widthRange) { Text(L(.annotateWidth)) }
                .labelsHidden()
                .frame(width: Metrics.Annotate.sizeSliderWidth)
                .accessibilityIdentifier("annotate.size")
                .onChange(of: width) { typing?.width = width }
        }
        .help(L(.annotateWidth))
    }

    private var canvas: some View {
        ZStack {
            Image(nsImage: image).resizable()
            Canvas { context, size in
                for mark in marks + [current].compactMap({ $0 }) { mark.draw(in: context, size: size) }
            }
        }
        .accessibilityIdentifier("annotate.canvas")
        .overlay(alignment: .topLeading) { textField }
        .aspectRatio(image.size, contentMode: .fit)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { canvasSize = $0 }
        .gesture(drawing)
    }

    @ViewBuilder
    private var textField: some View {
        if let mark = typing, let origin = mark.points.first {
            TextField(L(.annotateTextPlaceholder), text: Binding { typing?.text ?? "" } set: { typing?.text = $0 })
                .textFieldStyle(.plain)
                .font(.system(size: mark.fontSize(in: canvasSize), weight: .semibold))
                .foregroundStyle(mark.color)
                .fixedSize()
                .frame(minWidth: Metrics.Annotate.textFieldMinWidth, alignment: .leading)
                .overlay(Rectangle().strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: Metrics.hairline, dash: [Spacing.xs])))
                .offset(x: origin.x * canvasSize.width, y: origin.y * canvasSize.height)
                .focused($typingFocused)
                .onSubmit(commitText)
                .onExitCommand { typing = nil }
                // A new field for each text mark, focused once it's in the window.
                .id(mark.id)
                // After the click that placed it has finished; focusing during it doesn't stick.
                .task {
                    try? await Task.sleep(for: .milliseconds(50))
                    typingFocused = true
                }
                .accessibilityIdentifier("annotate.text")
        }
    }

    /// Keeps the text being typed as a mark, unless it's empty.
    private func commitText() {
        if let typing, !typing.text.trimmingCharacters(in: .whitespaces).isEmpty { marks.append(typing) }
        typing = nil
    }

    private var drawing: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard canvasSize.width > 0, canvasSize.height > 0, tool != .text else { return }
                let point = CGPoint(x: value.location.x / canvasSize.width, y: value.location.y / canvasSize.height)
                if current == nil {
                    current = AnnotationMark(tool: tool, color: color, width: width, points: [point], filled: filled)
                } else if tool == .pen || tool == .highlighter {
                    current?.points.append(point)
                } else {
                    current?.points = [current?.points.first ?? point, point]
                }
            }
            .onEnded { value in
                if tool == .text, canvasSize.width > 0, canvasSize.height > 0 {
                    // A click places a text field there; clicking elsewhere keeps the previous text.
                    commitText()
                    let point = CGPoint(x: value.location.x / canvasSize.width, y: value.location.y / canvasSize.height)
                    typing = AnnotationMark(tool: .text, color: color, width: width, points: [point])
                }
                if let current { marks.append(current) }
                current = nil
            }
    }

    private var footer: some View {
        HStack {
            Button(L(.actionCancel), action: onCancel).keyboardShortcut(typing == nil ? .cancelAction : nil)
            Spacer()
            Button(L(.actionSaveToFile)) {
                commitText()
                if let (png, _, _) = render() { FileExporter.save(png, name: L(.annotatedFileName), type: .png) }
            }
            Button(L(.actionCopy)) {
                commitText()
                if let (png, _, _) = render() { onCopy(png) }
            }
            .keyboardShortcut(typing == nil ? KeyboardShortcut("c") : nil)
            .accessibilityIdentifier("annotate.copy")
            Button(L(.annotateDone)) {
                commitText()
                if let (png, width, height) = render() { onDone(png, width, height) }
            }
            .keyboardShortcut(typing == nil ? .defaultAction : nil)
            .buttonStyle(.borderedProminent)
        }
    }

    /// The image at full size with the marks drawn on it.
    private func render() -> (Data, Int, Int)? {
        let pixels = image.pixelSize
        let content = ZStack {
            Image(nsImage: image).resizable()
            Canvas { context, size in for mark in marks { mark.draw(in: context, size: size) } }
        }
        .frame(width: pixels.width, height: pixels.height)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        let output = renderer.nsImage
        guard let png = output?.pngRepresentation else { return nil }
        return (png, Int(pixels.width), Int(pixels.height))
    }
}
