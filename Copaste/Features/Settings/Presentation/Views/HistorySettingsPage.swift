import SwiftUI

struct HistorySettingsPage: View {
    @Bindable var session: ClipboardSession
    var body: some View {
        SettingsGroup(L(.settingsHistory)) {
            SettingsRow(L(.settingsKeepHistory), symbol: "calendar.badge.clock") {
                Picker(L(.settingsKeepHistory), selection: $session.settings.retention) {
                    ForEach(Retention.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            SettingsRow(L(.settingsLinkPreviews), symbol: "link") {
                SettingsToggle(L(.settingsLinkPreviews), isOn: $session.settings.fetchLinkPreviews)
            }
            SettingsRow(L(.settingsUniversalClipboard), symbol: "laptopcomputer.and.iphone",
                        subtitle: L(.settingsUniversalClipboardFooter)) {
                SettingsToggle(L(.settingsUniversalClipboard), isOn: $session.settings.saveUniversalClipboard)
            }
        }
        SettingsGroup(L(.settingsTextRecognition), footer: L(.settingsTextRecognitionFooter)) {
            SettingsRow(L(.settingsTextRecognition), symbol: "text.viewfinder") {
                SettingsToggle(L(.settingsTextRecognition), isOn: $session.settings.textRecognition)
            }
            SettingsRow(L(.settingsRecognitionMode), symbol: "gauge.with.dots.needle.67percent") {
                Picker(L(.settingsRecognitionMode), selection: $session.settings.accurateRecognition) {
                    Text(.recognitionFast).tag(false)
                    Text(.recognitionAccurate).tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            .disabled(!session.settings.textRecognition)
        }
        StorageSection(session: session)
        DeleteEntriesSection(session: session)
    }
}
