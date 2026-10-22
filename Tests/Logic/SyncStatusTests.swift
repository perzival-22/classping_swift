// SyncStatusTests.swift: lib/sync.ts has no test file on the web, so every
// expected value here was printed by the web's own functions (WebValues14a.swift,
// "web:"). Run: tools/logic-test.sh. Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

/// The moment the web worked its text out at.
private let webNow = Date(timeIntervalSince1970: WEB_NOW_MS / 1000)

@Suite struct SyncStatusTests {
    // MARK: retries

    /// web: `retryDelay(0...7)`.
    @Test func retryDelaysMatchTheWeb() {
        #expect((0...7).map(retryDelay) == WEB_RETRY_DELAYS)
    }

    /// A negative attempt counts as the first (the web returns nothing; D-91).
    @Test func aNegativeAttemptWaitsTheFirstDelay() {
        #expect(retryDelay(-1) == 1_000)
    }

    // MARK: relative time

    /// web: `relativeTime` from the future through 29 days, every boundary
    /// (44.5 seconds rounds up to a minute, 1.5 days to two).
    @Test func relativeTimeMatchesTheWeb() {
        for (ago, text) in WEB_RELATIVE {
            #expect(relativeTime(WEB_NOW_MS - ago, now: webNow) == text, "ago: \(ago) ms")
        }
    }

    /// From 30 days on, the phone's own short date (D-91): not "ago" text.
    @Test func thirtyDaysAndMoreIsADate() {
        let text = relativeTime(WEB_NOW_MS - 31 * 86_400_000, now: webNow)
        #expect(!text.isEmpty)
        #expect(!text.contains("ago"))
        #expect(text != "yesterday")
    }

    /// Just under 30 days rounds up to 30, so the web prints a date there too
    /// (its value is the browser's own date, so it isn't pinned).
    @Test func justUnderThirtyDaysRoundsToADate() {
        let text = relativeTime(WEB_NOW_MS - 2_591_999_000, now: webNow)
        #expect(!text.contains("ago"))
    }

    // MARK: the chip and the Settings line

    /// web: `syncLabel` and `syncDetail` for fourteen statuses, an empty error included.
    @Test func labelsAndDetailsMatchTheWeb() {
        for c in WEB_STATUS_CASES {
            let state = SyncState(rawValue: c.state)
            #expect(state != nil, "state: \(c.state)")
            let status = SyncStatus(state: state ?? .saved, lastSyncedAt: c.lastSyncedAt,
                                    pending: c.pending, error: c.error)
            #expect(syncLabel(status) == c.label, "label for \(c.state), \(c.pending)")
            #expect(syncDetail(status, now: webNow) == c.detail, "detail for \(c.state), \(c.pending)")
        }
    }

    @Test func idleIsSavedWithNothingWaiting() {
        #expect(SyncStatus.idle == SyncStatus(state: .saved, lastSyncedAt: nil, pending: 0, error: nil))
        #expect(syncLabel(.idle) == "Saved on this device")
    }

    /// The rule the file exists for: "Synced" only in the synced state.
    @Test func onlyTheSyncedStateSaysSynced() {
        let states: [SyncState] = [.saved, .syncing, .offline, .error]
        for state in states {
            let status = SyncStatus(state: state, lastSyncedAt: WEB_NOW_MS, pending: 1, error: nil)
            #expect(syncLabel(status) != "Synced")
        }
    }

    // MARK: errors

    /// web: `describeSyncError` and `isAuthError` for sixteen messages.
    @Test func errorWordsMatchTheWeb() {
        for (message, text, auth) in WEB_ERRORS {
            #expect(describeSyncError(message) == text, "message: \(message)")
            #expect(isAuthError(message) == auth, "message: \(message)")
        }
    }
}
