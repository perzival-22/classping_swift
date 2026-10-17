// Phase 6a: profile quotes and corrected Note keys survive planner reloads.
// scripts/test-store.sh isolates the Documents directory for these tests.
import Foundation
import Testing
@testable import CPLogic

@MainActor
@Suite(.serialized) struct TodayPersistenceTests {
    private func freshStore() -> Store {
        try? FileManager.default.removeItem(at: Store.fileURL)
        return Store()
    }

    @Test func savesPersonalQuotesAndRestoresBuiltInRotationAfterClearing() {
        let store = freshStore()
        store.profile.quotes = normalizeQuotes(["  Keep going  ", "", "Start small"])
        store.save()
        #expect(!store.lastSaveFailed)
        let loaded = Store.load()
        #expect(loaded.profile.quotes == ["Keep going", "Start small"])
        #expect(quoteFor(loaded.profile.quotes, Date(timeIntervalSince1970: 7200)) == "Start small")
        loaded.profile.quotes = []
        loaded.save()
        #expect(!loaded.lastSaveFailed)
        #expect(Store.load().profile.quotes.isEmpty)
        #expect(quoteFor(Store.load().profile.quotes, Date(timeIntervalSince1970: 0))
                == defaultQuotes[0])
    }

    @Test func failedQuoteSaveCanBeRetried() {
        let store = freshStore()
        let created = (try? FileManager.default.createDirectory(
            at: Store.fileURL, withIntermediateDirectories: false)) != nil
        #expect(created)
        guard created else { return }
        store.profile.quotes = ["Try again"]
        store.save()
        #expect(store.lastSaveFailed)
        try? FileManager.default.removeItem(at: Store.fileURL)
        store.save()
        #expect(!store.lastSaveFailed)
        #expect(Store.load().profile.quotes == ["Try again"])
    }

    @Test func noteUsesCorrectedKeysAndRoundTripsWithPlanner() {
        let store = freshStore()
        let note = Note(courseID: nil, date: "2026-10-17", title: "Lecture",
                        body: "Remember this", assignmentID: UUID(),
                        updatedAt: Date(timeIntervalSince1970: 1_800_000_000))
        store.notes = [note]
        store.save()
        #expect(!store.lastSaveFailed)
        #expect(Store.load().notes == [note])
        let data = try? Data(contentsOf: Store.fileURL)
        let json = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        #expect(json.contains("\"assignmentID\""))
        #expect(json.contains("\"updatedAt\""))
        #expect(!json.contains("\"assignemntID\""))
        #expect(!json.contains("\"updateAt\""))
    }
}
