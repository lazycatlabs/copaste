import Foundation
import Testing
@testable import ReCopy

struct AppDefaultsMigrationTests {
    @Test func copiesCopastePreferencesOnceWithoutOverwriting() throws {
        let oldName = "com.lazycatlabs.recopy.tests.old-\(UUID().uuidString)"
        let newName = "com.lazycatlabs.recopy.tests.new-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: newName))
        defer {
            defaults.removePersistentDomain(forName: oldName)
            defaults.removePersistentDomain(forName: newName)
        }
        defaults.setPersistentDomain(["vaultBookmark": Data([1, 2]), "textSize": "large"], forName: oldName)
        defaults.set("small", forKey: "textSize")

        AppDefaults.migrateFromCopaste(into: defaults, from: oldName)
        #expect(defaults.data(forKey: "vaultBookmark") == Data([1, 2]))
        #expect(defaults.string(forKey: "textSize") == "small")

        defaults.removeObject(forKey: "vaultBookmark")
        AppDefaults.migrateFromCopaste(into: defaults, from: oldName)
        #expect(defaults.data(forKey: "vaultBookmark") == nil)
    }
}
