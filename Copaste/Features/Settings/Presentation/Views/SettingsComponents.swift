import Observation
import SwiftUI

/// Which Settings pane is shown. Shared, so other windows can open Settings on a given pane.
@Observable
final class SettingsNavigation {
    static let shared = SettingsNavigation()
    var pane: SettingsPane? = .general
}

/// A Settings pane: big title and subtitle on top, then its groups.
struct SettingsPaneLayout<Content: View>: View {
    let pane: SettingsPane
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(pane.title).font(.scaled(.largeTitle, weight: .bold))
                    Text(pane.subtitle).font(.scaled(.title3)).foregroundStyle(.secondary)
                }
                content
            }
            .padding(.horizontal, Spacing.hero)
            .padding(.vertical, Spacing.page)
            .frame(maxWidth: Metrics.Settings.pageMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityIdentifier("settings.page.\(pane.rawValue)")
    }
}

/// A titled card of rows, separated by lines; an optional note underneath.
struct SettingsGroup<Content: View, Header: View>: View {
    let title: String
    var footer: String?
    @ViewBuilder let header: Header
    @ViewBuilder let content: Content

    init(_ title: String, footer: String? = nil, @ViewBuilder header: () -> Header = { EmptyView() },
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.header = header()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text(title).font(.scaled(.headline))
                Spacer()
                header
            }
            VStack(spacing: 0) {
                Group(subviews: content) { rows in
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        if index > 0 { Divider().padding(.leading, Metrics.Settings.rowTextInset) }
                        row
                    }
                }
            }
            .background(Color.primary.opacity(Opacity.hover), in: .rect(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(.primary.opacity(Opacity.tint)))
            if let footer {
                Text(footer).font(.scaled(.callout)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// One setting: an icon, a title with an optional explanation, and its control on the right.
struct SettingsRow<Control: View>: View {
    let symbol: String
    let title: String
    var subtitle: String?
    @ViewBuilder let control: Control

    init(_ title: String, symbol: String, subtitle: String? = nil, @ViewBuilder control: () -> Control) {
        self.title = title
        self.symbol = symbol
        self.subtitle = subtitle
        self.control = control()
    }

    var body: some View {
        HStack(spacing: Spacing.xl) {
            Image(systemName: symbol)
                .font(.scaled(.title3))
                .foregroundStyle(.secondary)
                .frame(width: Metrics.Settings.rowIcon)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title).font(.scaled(.body, weight: .medium))
                if let subtitle {
                    Text(subtitle).font(.scaled(.callout)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Spacing.xl)
            control
        }
        .padding(.horizontal, Spacing.xxl)
        .padding(.vertical, Spacing.xl)
        .accessibilityElement(children: .contain)
    }
}

/// A setting's on/off switch. The title is hidden, as the row shows it, but VoiceOver still reads it.
struct SettingsToggle: View {
    let title: String
    @Binding var isOn: Bool

    init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        _isOn = isOn
    }

    var body: some View {
        Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch)
    }
}
