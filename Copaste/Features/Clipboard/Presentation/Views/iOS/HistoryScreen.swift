#if os(iOS)
import SwiftUI
import UniformTypeIdentifiers

/// The vault's history on iPhone and iPad. iOS doesn't let apps watch the clipboard, so it is read when
/// Copaste opens (if allowed in Settings) or with the Paste button, which never shows the paste prompt.
struct HistoryScreen: View {
    @Environment(ClipboardSession.self) private var session
    @State private var model = ClipboardViewModel()
    @State private var showsSettings = false

    var body: some View {
        NavigationStack {
            let sections = model.sections(of: session)
            List {
                ForEach(sections, id: \.0) { section, items in
                    Section(section.title) {
                        ForEach(items) { item in row(item) }
                    }
                }
            }
            .overlay {
                if sections.isEmpty {
                    ContentUnavailableView(L(.emptyTitle), systemImage: "list.clipboard", description: Text(.emptyMessageIOS))
                }
            }
            .searchable(text: $model.query, prompt: L(.searchPlaceholder))
            .refreshable { await session.reload() }
            .navigationTitle(L(.appName))
            .navigationDestination(for: UUID.self) { ClipDetailScreen(id: $0) }
            .toolbar { toolbar }
            .sheet(isPresented: $showsSettings) {
                NavigationStack {
                    SettingsView().toolbar {
                        Button(L(.actionDone)) { showsSettings = false }
                    }
                }
            }
        }
    }

    private func row(_ item: ClipItem) -> some View {
        NavigationLink(value: item.id) {
            ClipRowView(item: item, query: model.query)
        }
        .swipeActions(edge: .leading) {
            Button(L(.actionCopy), systemImage: "doc.on.doc") { session.copy(item) }.tint(.accentColor)
        }
        .swipeActions(edge: .trailing) {
            Button(L(.actionDelete), systemImage: "trash", role: .destructive) { session.delete(item) }
            Button(item.pinned ? L(.actionUnpin) : L(.actionPin), systemImage: "pin") { session.togglePin(item) }.tint(.orange)
        }
        .contextMenu {
            Button(L(.actionCopy), systemImage: "doc.on.doc") { session.copy(item) }
            Button(item.pinned ? L(.actionUnpin) : L(.actionPin), systemImage: "pin") { session.togglePin(item) }
            Button(L(.actionDelete), systemImage: "trash", role: .destructive) { session.delete(item) }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(L(.settingsTitle), systemImage: "gearshape") { showsSettings = true }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu(L(.filterAllTypes), systemImage: "line.3.horizontal.decrease") {
                Picker(L(.filterAllTypes), selection: $model.kind) {
                    Label(L(.filterAllTypes), systemImage: "square.grid.2x2").tag(ClipKind?.none)
                    ForEach(ClipKind.allCases, id: \.self) { Label($0.title, systemImage: $0.symbolName).tag(ClipKind?.some($0)) }
                }
            }
            PasteButton(supportedContentTypes: [.image, .url, .utf8PlainText]) { providers in
                Task {
                    guard let content = await SystemPasteboard.content(from: providers) else { return }
                    session.handle(Capture(content: content))
                }
            }
            .labelStyle(.iconOnly)
        }
    }
}

/// One entry: its content, what can be done with it, and its information.
struct ClipDetailScreen: View {
    let id: UUID
    @Environment(ClipboardSession.self) private var session
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var annotating = false
    @State private var copied = 0

    var body: some View {
        if let item = session.items.first(where: { $0.id == id }) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.page) {
                    ClipPreviewView(item: item)
                        .frame(maxWidth: .infinity, maxHeight: Metrics.Detail.previewMaxHeight * 2, alignment: .topLeading)
                    actions(item)
                    ClipInfoView(item: item)
                }
                .padding(Spacing.page)
            }
            .navigationTitle(item.kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .sensoryFeedback(.success, trigger: copied)
            .fullScreenCover(isPresented: $annotating) { annotator(item) }
        }
    }

    private func actions(_ item: ClipItem) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: Metrics.Panel.actionsWidth / 2))], spacing: Spacing.md) {
            ForEach(ClipAction.available(for: item, isMac: false)) { action in
                if action == .share {
                    shareLink(item)
                } else {
                    Button(role: action == .delete ? .destructive : nil) { perform(action, on: item) } label: {
                        Label(action.title(for: item), systemImage: action.symbolName).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    @ViewBuilder
    private func shareLink(_ item: ClipItem) -> some View {
        let label = Label(L(.actionShare), systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
        Group {
            if item.kind == .image, let url = session.blobURL(item.blob) {
                ShareLink(item: url) { label }
            } else if let url = item.url, item.kind == .link {
                ShareLink(item: url) { label }
            } else {
                ShareLink(item: item.text ?? item.title) { label }
            }
        }
        .buttonStyle(.bordered)
    }

    private func perform(_ action: ClipAction, on item: ClipItem) {
        switch action {
        case .copy: session.copy(item)
        case .copyHex: item.color.map { session.copy(item, as: $0.hex) }
        case .copyRGB: item.color.map { session.copy(item, as: $0.rgb) }
        case .copyHSL: item.color.map { session.copy(item, as: $0.hsl) }
        case .open, .composeEmail: if let url = item.url { openURL(url) }
        case .annotate: annotating = true
        case .pin: session.togglePin(item)
        case .delete:
            dismiss()
            session.delete(item)
        case .paste, .saveToFile, .revealInFinder, .share: break
        }
        if [.copy, .copyHex, .copyRGB, .copyHSL].contains(action) { copied += 1 }
    }

    @ViewBuilder
    private func annotator(_ item: ClipItem) -> some View {
        if let image = session.blobURL(item.blob).flatMap(ImageCache.image) {
            AnnotationEditor(image: image) { png, width, height in
                session.addImage(png, width: width, height: height)
                annotating = false
                copied += 1
            } onCancel: {
                annotating = false
            }
        }
    }
}

/// Picks the vault on first run, then shows the history; reads the clipboard whenever Copaste comes to the front.
struct IOSRootView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        if let session = container.session {
            @Bindable var session = session
            HistoryScreen()
                .environment(session)
                .onChange(of: scenePhase, initial: true) { _, phase in
                    guard phase == .active else { return }
                    Task {
                        await session.reload()
                        if session.settings.captureOnOpen { session.captureFromPasteboard() }
                    }
                }
                .alert(L(.errorTitle),
                       isPresented: Binding(get: { session.errorMessage != nil }, set: { _ in session.errorMessage = nil })) {
                    Button(L(.actionOK)) {}
                } message: {
                    Text(session.errorMessage ?? "")
                }
        } else {
            VaultPickerView()
        }
    }
}
#endif
