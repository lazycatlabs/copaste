import SwiftUI

struct AppearanceSettingsPage: View {
    @Bindable var session: ClipboardSession

    var body: some View {
        SettingsGroup(L(.settingsTextSize), footer: L(.settingsTextSizeFooter)) {
            SettingsRow(L(.settingsTextSize), symbol: "textformat.size") {
                Picker(L(.settingsTextSize), selection: Bindable(TextScale.shared).size) {
                    ForEach(TextSize.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
        }
        SettingsGroup(L(.settingsClipboardWindow)) {
            SettingsRow(L(.settingsShowToasts), symbol: "checkmark.bubble") {
                SettingsToggle(L(.settingsShowToasts), isOn: $session.settings.showToasts)
            }
            SettingsRow(L(.settingsWindowPosition), symbol: "macwindow", subtitle: L(.settingsWindowPositionHint)) {
                Button(L(.actionCenter)) { PanelPlacement.save(.zero) }.accessibilityIdentifier("settings.centerWindow")
            }
        }
    }
}
