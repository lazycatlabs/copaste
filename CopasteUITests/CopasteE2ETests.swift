import AppKit
import XCTest

/// End-to-end tests: launch the real app (in its `-e2e` mode: a throwaway vault with sample entries, a private
/// clipboard and separate preferences) and use it as a person would. Each test saves screenshots of what it checks.
///
/// Run with `scripts/e2e.sh`, which also collects the screenshots into `e2e-output/` (ignored by git).
final class CopasteE2ETests: XCTestCase {
    private var app: XCUIApplication!
    private let finder = XCUIApplication(bundleIdentifier: "com.apple.finder")
    private let timeout: TimeInterval = 10

    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        app?.terminate()
    }

    // MARK: Clipboard window

    func test01PanelHasNewLookAndAnyDayFilter() {
        launch(open: "panel:image")
        XCTAssertTrue(element("panel.search").waitForExistence(timeout: timeout))
        XCTAssertEqual(element("panel.dateFilter").title, "Any Day", "Date filter reads “Any Day”")
        XCTAssertEqual(element("panel.search").placeholderValue, "Search your clipboard")
        XCTAssertTrue(panel.staticTexts["Pinned"].exists)
        XCTAssertTrue(panel.staticTexts["Today"].exists)
        XCTAssertTrue(panel.staticTexts["1440 × 900"].exists, "Info table shows the image size")
        screenshot(panel, "01-panel-new-look")

        element("panel.dateFilter").click()
        XCTAssertTrue(app.menuItems["Any Day"].waitForExistence(timeout: timeout))
        screenshotAroundPanel("02-date-filter-any-day")
        app.typeKey(.escape, modifierFlags: [])
    }

    func test02ActionsMenuShowsKeyCaps() {
        launch(open: "panel:image")
        XCTAssertTrue(element("panel.search").waitForExistence(timeout: timeout))
        XCTAssertEqual(element("panel.actions").label, "Actions, ⌘, K", "Footer shows ⌘ K as separate key caps")
        panel.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(element("panel.actionsMenu").waitForExistence(timeout: timeout))
        XCTAssertTrue(element("panel.actionsMenu").buttons["Annotate, ⌘, E"].exists, "Annotate shows its ⌘ E key caps")
        screenshot(panel, "03-actions-menu-key-caps")
    }

    func test03PanelDragsAndSnapsToScreenCenter() throws {
        launch(open: "panel", extra: ["-e2eGuides"])
        XCTAssertTrue(element("panel.search").waitForExistence(timeout: timeout))
        let start = panel.frame
        let screen = try XCTUnwrap(visibleFrame(containing: start))

        // Away from the center: the window follows the pointer.
        drag(by: CGVector(dx: -220, dy: 140))
        let moved = panel.frame
        XCTAssertEqual(moved.minX, start.minX - 220, accuracy: 2)
        XCTAssertEqual(moved.minY, start.minY + 140, accuracy: 2)

        // Close to the center: the window snaps onto both center lines.
        let target = CGPoint(x: screen.midX + 9, y: screen.midY - 7)
        drag(by: CGVector(dx: target.x - moved.midX, dy: target.y - moved.midY))
        let snapped = panel.frame
        XCTAssertEqual(snapped.midX, screen.midX, accuracy: 1)
        XCTAssertEqual(snapped.midY, screen.midY, accuracy: 1)
        screenshotAroundPanel("04-panel-snapped-to-center-with-guides")

        // The position is remembered the next time the window opens.
        app.terminate()
        launch(open: "panel", keepDefaults: true)
        XCTAssertTrue(element("panel.search").waitForExistence(timeout: timeout))
        XCTAssertEqual(panel.frame.midX, screen.midX, accuracy: 1)
        XCTAssertEqual(panel.frame.midY, screen.midY, accuracy: 1)
    }

    func test04ClosingPanelGivesFocusBack() {
        launch()
        finder.activate()
        XCTAssertTrue(finder.wait(for: .runningForeground, timeout: timeout))
        send("panel")
        XCTAssertTrue(element("panel.search").waitForExistence(timeout: timeout))
        panel.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(waitUntil { !self.element("panel.search").exists })
        XCTAssertTrue(finder.wait(for: .runningForeground, timeout: timeout), "The app the user was in is in front again")
    }

    // MARK: Settings

    func test05SettingsOpensFocused() {
        launch()
        finder.activate()
        XCTAssertTrue(finder.wait(for: .runningForeground, timeout: timeout))
        send("settings")
        XCTAssertTrue(app.windows["settings"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: timeout), "Settings comes to the front")
        screenshot(app.windows["settings"], "06-settings-focused")
    }

    func test06ShortcutsCanBeChangedInSettings() {
        launch(open: "settings")
        let settings = app.windows["settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: timeout))
        openSettingsPage("shortcuts", in: settings)
        let actions = settings.buttons["settings.shortcut.actions"]
        reveal(actions, in: settings)
        XCTAssertEqual(actions.title.isEmpty ? actions.label : actions.title, "⌘K")
        XCTAssertTrue(settings.buttons["settings.shortcut.openHistory"].exists)
        screenshot(settings, "07-settings-shortcuts")

        actions.click()
        settings.typeKey("j", modifierFlags: .command)
        XCTAssertTrue(waitUntil { (actions.title.isEmpty ? actions.label : actions.title) == "⌘J" }, "Recorded ⌘J")
        screenshot(settings, "08-settings-shortcut-changed")

        send("panel:image")
        XCTAssertTrue(element("panel.search").waitForExistence(timeout: timeout))
        XCTAssertEqual(element("panel.actions").label, "Actions, ⌘, J", "Footer shows the new keys")
        panel.typeKey("j", modifierFlags: .command)
        XCTAssertTrue(element("panel.actionsMenu").waitForExistence(timeout: timeout), "⌘J opens Actions")
        screenshot(panel, "09-custom-shortcut-opens-actions")
    }

    // MARK: Annotate

    func test07AnnotateOpensFocused() {
        launch()
        finder.activate()
        XCTAssertTrue(finder.wait(for: .runningForeground, timeout: timeout))
        send("annotate")
        XCTAssertTrue(app.windows["annotate"].waitForExistence(timeout: timeout))
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: timeout), "The annotation editor comes to the front")
        screenshot(app.windows["annotate"], "10-annotate-focused")
    }

    func test08AnnotateAddsText() {
        launch(open: "annotate")
        let editor = app.windows["annotate"]
        XCTAssertTrue(editor.waitForExistence(timeout: timeout))
        let textTool = editor.radioButtons["Text"]
        XCTAssertTrue(textTool.waitForExistence(timeout: timeout))
        textTool.click()

        let canvas = element("annotate.canvas")
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.08, dy: 0.62)).click()
        let field = element("annotate.text")
        XCTAssertTrue(field.waitForExistence(timeout: timeout))
        app.typeText("Best quarter yet!")
        XCTAssertEqual(field.value as? String, "Best quarter yet!")
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(waitUntil { !field.exists }, "↩ keeps the text on the image")
        XCTAssertTrue(editor.exists, "↩ doesn't close the editor while typing")
        screenshot(editor, "11-annotate-text-added")

        editor.buttons["Save as New Entry"].click()
        let toast = app.descendants(matching: .any).matching(NSPredicate(format: "identifier IN {'panel.toast', 'toast'}")).firstMatch
        XCTAssertTrue(toast.waitForExistence(timeout: timeout), "The annotated copy is saved")
        screenshot(panel, "12-annotated-image-saved")
    }

    func test09AnnotateCopiesToClipboard() {
        let clipboard = NSPasteboard(name: NSPasteboard.Name("com.lazycatlabs.copaste.e2e"))
        clipboard.clearContents()
        launch(open: "annotate")
        let editor = app.windows["annotate"]
        XCTAssertTrue(editor.waitForExistence(timeout: timeout))
        editor.radioButtons["Rectangle"].click()
        let canvas = element("annotate.canvas")
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.05))
            .click(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)))
        screenshot(editor, "13-annotate-copy-button")

        element("annotate.copy").click()
        XCTAssertTrue(waitUntil { !editor.exists }, "Copying closes the editor")
        XCTAssertTrue(waitUntil { NSImage(pasteboard: clipboard) != nil }, "The edited image is on the clipboard")
        if let image = NSImage(pasteboard: clipboard) {
            let attachment = XCTAttachment(image: image)
            attachment.name = "14-copied-annotated-image"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    // MARK: Quick paste, groups, Settings pages

    func test10HoldingCommandShowsQuickPasteKeys() {
        launch(open: "panel")
        XCTAssertTrue(element("panel.search").waitForExistence(timeout: timeout))
        XCTAssertFalse(element("row.quickKey").exists)
        // XCUITest's own modifier holding doesn't send the ⌘ key-down the app listens for, so it's sent through the app.
        send("command:down")
        XCTAssertTrue(element("row.quickKey").waitForExistence(timeout: timeout), "⌘ shows ⌘1…⌘9 on the rows")
        // All eight sample entries fit within ⌘1…⌘9.
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "row.quickKey").count, 8)
        screenshot(panel, "15-hold-command-quick-paste-keys")
        send("command:up")
        XCTAssertTrue(waitUntil { !self.element("row.quickKey").exists }, "Releasing ⌘ hides them")
    }

    func test11GroupsFilterAndAssign() {
        launch(open: "panel")
        XCTAssertTrue(element("panel.search").waitForExistence(timeout: timeout))
        let rows = { self.panel.scrollViews.firstMatch.staticTexts.count }
        let all = rows()

        // Filter by the "Work" group: only its two entries are left.
        element("panel.groupFilter").click()
        app.menuItems["Work"].click()
        XCTAssertEqual(element("panel.groupFilter").title, "Work")
        XCTAssertTrue(waitUntil { rows() < all })
        XCTAssertTrue(panel.staticTexts["Work"].exists, "Entries show their group")
        screenshot(panel, "16-groups-filtered-by-work")

        // Back to all, then put the selected entry in "Design" from Actions (⌘K).
        element("panel.groupFilter").click()
        app.menuItems["All Groups"].click()
        panel.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(element("panel.actionsGroup").waitForExistence(timeout: timeout))
        screenshot(panel, "17-groups-in-actions-menu")
        element("panel.actionsGroup").click()
        app.menuItems["Design"].click()
        XCTAssertTrue(waitUntil { self.panel.staticTexts["Design"].exists }, "The entry is now in Design")
        screenshot(panel, "18-entry-added-to-design")
    }

    func test12SettingsSidebarPagesAndSearch() {
        launch(open: "settings")
        let settings = app.windows["settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: timeout))
        XCTAssertTrue(element("settings.page.general").waitForExistence(timeout: timeout))
        screenshot(settings, "19-settings-general")

        openSettingsPage("appearance", in: settings)
        XCTAssertTrue(app.buttons["settings.centerWindow"].exists, "Window position can be reset")
        screenshot(settings, "20-settings-appearance")

        openSettingsPage("groups", in: settings)
        XCTAssertEqual(settings.textFields.matching(identifier: "settings.groupName").count, 2)
        settings.buttons["settings.addGroup"].click()
        XCTAssertTrue(waitUntil { settings.textFields.matching(identifier: "settings.groupName").count == 3 }, "Add Group adds one")
        screenshot(settings, "21-settings-groups")

        // Searching for a setting opens the page it's on.
        let search = settings.searchFields.firstMatch
        search.click()
        search.typeText("sound")
        XCTAssertTrue(element("settings.page.pasting").waitForExistence(timeout: timeout), "“sound” finds Pasting")
        screenshot(settings, "22-settings-search")
    }

    func test13UpdatesAndChangelogInSettings() {
        launch(open: "settings")
        let settings = app.windows["settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: timeout))
        openSettingsPage("updates", in: settings)
        // E2E runs see a sample 9.9.0 release instead of the network.
        XCTAssertTrue(settings.buttons["settings.updateDownload"].waitForExistence(timeout: timeout), "A newer version offers Download")
        XCTAssertTrue(element("settings.release.9.9.0").exists, "The changelog lists the new version")
        XCTAssertTrue(element("settings.release.0.1.1").exists, "…and the installed one")
        screenshot(settings, "23-settings-updates-changelog")
    }

    func test14StorageAndDeletingEntriesByType() {
        launch(open: "settings")
        let settings = app.windows["settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: timeout))
        openSettingsPage("history", in: settings)

        let storage = element("settings.storageUsed")
        reveal(storage, in: settings)
        XCTAssertTrue(waitUntil { storage.value as? String != "Calculating…" && (storage.value as? String)?.contains("B") == true },
                      "Shows the space the history takes")

        // Only colours: the two sample colours match.
        let type = settings.popUpButtons["settings.cleanupType"]
        reveal(type, in: settings)
        type.click()
        app.menuItems["Color"].click()
        let matches = element("settings.cleanupMatches")
        reveal(matches, in: settings)
        XCTAssertTrue(settings.staticTexts["2 entries match"].waitForExistence(timeout: timeout), "Two colours match")
        screenshot(settings, "24-settings-storage-and-delete")

        settings.buttons["settings.cleanupDelete"].click()
        // The confirmation's button, in the Settings window (the Touch Bar has one with the same name).
        let confirm = settings.buttons["Delete"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: timeout))
        confirm.click()
        XCTAssertTrue(settings.staticTexts["0 entries match"].waitForExistence(timeout: timeout), "The colours are gone")

        send("panel")
        XCTAssertTrue(element("panel.search").waitForExistence(timeout: timeout))
        XCTAssertFalse(panel.staticTexts["#FF8C3C"].exists, "Deleted entries leave the history")
    }

    func test15SelectingSeveralEntriesPastesThemTogether() {
        launch(open: "panel")
        XCTAssertTrue(element("panel.search").waitForExistence(timeout: timeout))
        // Holding ⌘ shows the quick-paste keys, which renames the rows "row.quickKey".
        let rows = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'row'"))
        rows.element(boundBy: 0).click()
        XCUIElement.perform(withKeyModifiers: .command) { rows.element(boundBy: 2).click() }
        XCTAssertTrue(waitUntil { self.element("panel.primary").label.contains("2 Entries") }, "⌘-click adds a second entry")
        screenshot(panel, "25-two-entries-selected")

        XCUIElement.perform(withKeyModifiers: .shift) { rows.element(boundBy: 4).click() }
        XCTAssertTrue(waitUntil { self.element("panel.primary").label.contains("4 Entries") }, "⇧-click selects the range")
        screenshot(panel, "26-range-selected")

        panel.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(waitUntil { !self.element("panel.primary").label.contains("Entries") }, "esc clears the selection")
    }

    func test16NotesAreSavedAndSearchable() {
        launch(open: "panel")
        XCTAssertTrue(element("panel.search").waitForExistence(timeout: timeout))
        let note = element("panel.note")
        XCTAssertTrue(note.waitForExistence(timeout: timeout))
        note.click()
        note.typeText("quarterly invoice")
        screenshot(panel, "27-note-added")

        // esc leaves the note for the search field.
        panel.typeKey(.escape, modifierFlags: [])
        panel.typeText("quarterly")
        let rows = app.descendants(matching: .any).matching(identifier: "row")
        XCTAssertTrue(waitUntil { rows.count == 1 }, "Searching finds the entry by its note")
        screenshot(panel, "28-note-found-by-search")
        // The row's texts are combined into its accessibility value.
        XCTAssertTrue(waitUntil { (rows.firstMatch.value as? String)?.contains("quarterly invoice") == true },
                      "The row shows the matching note")
    }

    // MARK: Welcome

    func test17OnboardingShowsOnceBeforeVaultPicker() {
        launch(open: "welcome")
        let welcome = app.windows["welcome"]
        XCTAssertTrue(welcome.waitForExistence(timeout: timeout))
        XCTAssertTrue(element("onboarding.page.welcome").waitForExistence(timeout: timeout), "First launch shows the introduction")
        XCTAssertTrue(welcome.staticTexts["Welcome to Copaste"].exists)
        XCTAssertTrue(element("onboarding.credit").exists, "The introduction credits Lazycatlabs")
        XCTAssertFalse(element("vault.choose").exists)
        screenshot(welcome, "29-onboarding-welcome")

        // The shortcut page lights its key caps when the shortcut is pressed.
        element("onboarding.next").click()
        XCTAssertTrue(element("onboarding.page.shortcut").waitForExistence(timeout: timeout))
        welcome.typeKey("v", modifierFlags: [.command, .shift])
        XCTAssertTrue(element("onboarding.shortcutDone").waitForExistence(timeout: timeout), "Trying the shortcut is confirmed")
        screenshot(welcome, "30-onboarding-shortcut-tried")

        // → turns the page too.
        welcome.typeKey(.rightArrow, modifierFlags: [])
        XCTAssertTrue(element("onboarding.page.sync").waitForExistence(timeout: timeout), "→ goes to the next page")
        screenshot(welcome, "31-onboarding-sync")
        element("onboarding.next").click()
        XCTAssertTrue(element("onboarding.page.organize").waitForExistence(timeout: timeout))
        screenshot(welcome, "32-onboarding-organize")

        element("onboarding.start").click()
        XCTAssertTrue(element("vault.choose").waitForExistence(timeout: timeout), "Get Started leads to the folder picker")
        XCTAssertTrue(element("onboarding.credit").exists)
        screenshot(welcome, "33-onboarding-vault-picker")

        // Seen once: the next welcome window goes straight to the folder picker.
        app.terminate()
        launch(open: "welcome", keepDefaults: true)
        XCTAssertTrue(element("vault.choose").waitForExistence(timeout: timeout))
        XCTAssertFalse(element("onboarding.page.welcome").exists, "The introduction isn't shown again")
    }

    func test18AboutShowsTheLicense() {
        launch(open: "settings")
        let settings = app.windows["settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: timeout))
        openSettingsPage("about", in: settings)
        XCTAssertTrue(element("settings.license").waitForExistence(timeout: timeout), "About links to the GPL-3.0 license")
        screenshot(settings, "34-settings-about-license")
    }

    // MARK: Helpers

    private func openSettingsPage(_ page: String, in settings: XCUIElement) {
        let item = settings.descendants(matching: .any)["settings.nav.\(page)"].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: timeout))
        item.click()
        XCTAssertTrue(element("settings.page.\(page)").waitForExistence(timeout: timeout))
    }

    private var panel: XCUIElement { app.dialogs["clipboardPanel"] }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func launch(open: String? = nil, extra: [String] = [], keepDefaults: Bool = false) {
        app = XCUIApplication()
        app.launchArguments = ["-e2e", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
            + (open.map { ["-e2eOpen", $0] } ?? []) + (keepDefaults ? ["-e2eKeepDefaults"] : []) + extra
        app.launch()
    }

    /// Sends a command to the running app (see `E2EFixtures`), without bringing it to the front.
    private func send(_ command: String) {
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.lazycatlabs.copaste.e2e"), object: command, userInfo: nil, deliverImmediately: true)
    }

    /// Drags the window by its bottom bar.
    private func drag(by offset: CGVector) {
        let handle = panel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
        handle.click(forDuration: 0.2, thenDragTo: handle.withOffset(offset))
    }

    /// The visible area of the screen holding `frame`, in the same top-left coordinates XCUITest uses.
    private func visibleFrame(containing frame: CGRect) -> CGRect? {
        guard let primary = NSScreen.screens.first?.frame else { return nil }
        return NSScreen.screens.map { screen in
            let visible = screen.visibleFrame
            return CGRect(x: visible.minX, y: primary.maxY - visible.maxY, width: visible.width, height: visible.height)
        }
        .first { $0.contains(CGPoint(x: frame.midX, y: frame.midY)) }
    }

    /// Scrolls the window's list in small steps until the element is inside it. Big steps get accelerated by macOS
    /// and overshoot.
    private func reveal(_ element: XCUIElement, in window: XCUIElement) {
        // The page, not the sidebar.
        let list = window.scrollViews.matching(NSPredicate(format: "identifier BEGINSWITH 'settings.page.'")).firstMatch
        let visible = list.frame.insetBy(dx: 0, dy: 40)
        for _ in 0..<80 where !visible.contains(element.frame) {
            list.scroll(byDeltaX: 0, deltaY: element.frame.midY > visible.midY ? -8 : 8)
        }
        XCTAssertTrue(window.frame.contains(element.frame), "Scrolled into view")
    }

    private func waitUntil(_ condition: @escaping () -> Bool) -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if condition() { return true }
            RunLoop.current.run(until: .now.addingTimeInterval(0.2))
        }
        return condition()
    }

    /// The screen around the clipboard window only (menus and guides reach past it), so nothing else the user
    /// has open ends up in the report.
    private func screenshotAroundPanel(_ name: String) {
        let shot = XCUIScreen.main.screenshot().image
        let frame = panel.frame.insetBy(dx: -120, dy: -120)
        guard let cg = shot.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let primary = NSScreen.screens.first?.frame else { return screenshot(panel, name) }
        let scale = CGFloat(cg.width) / primary.width
        let crop = CGRect(x: frame.minX * scale, y: frame.minY * scale, width: frame.width * scale, height: frame.height * scale)
            .intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard let cropped = cg.cropping(to: crop) else { return screenshot(panel, name) }
        let attachment = XCTAttachment(image: NSImage(cgImage: cropped, size: .zero))
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Kept in the test report; scripts/e2e.sh copies it to e2e-output/screenshots/<name>.png.
    private func screenshot(_ source: XCUIScreenshotProviding, _ name: String) {
        let attachment = XCTAttachment(screenshot: source.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
