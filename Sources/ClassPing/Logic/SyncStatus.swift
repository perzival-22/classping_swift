//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/SyncStatus.swift
//  Phase:   14a (the sync rules, before any network)
//  Ports:   lib/sync.ts (`SyncState`, `SyncStatus`, `IDLE_STATUS`,
//           `RETRY_DELAYS_MS`, `retryDelay`, `syncLabel`, `syncDetail`,
//           `relativeTime`, `isAuthError`, `describeSyncError`)
//
//  Summary: What the app is allowed to say about where your work has got to.
//           The one rule everything here follows: never say "Synced" before
//           the server has confirmed. The words come straight from the web.
//           Nothing here touches the network; Phase 14c drives it.
//

import Foundation

// MARK: - The states

/// Where things stand, weakest true statement first. "Saved" is always true,
/// because the phone writes every change to its own storage before any
/// network call. The raw text is the web's.
enum SyncState: String, Sendable {
    /// Written to this phone. Nothing sent yet, or there's no account.
    case saved
    /// A send is under way. The phone's copy is safe; the server hasn't said yes.
    case syncing
    /// The server has confirmed everything this phone has.
    case synced
    /// Known to be offline, with changes waiting.
    case offline
    /// A send failed for a reason trying again may not fix. The student should know.
    case error
}

/// One snapshot of the sync state, with the numbers the words need.
struct SyncStatus: Equatable, Sendable {
    var state: SyncState
    /// When the server last confirmed, in milliseconds since 1970 (the web's
    /// `Date.now()`), or nil if this phone never has. Saved across relaunches.
    var lastSyncedAt: Double?
    /// How many records have changes the server hasn't confirmed.
    var pending: Int
    /// Only in the `error` state. Written for a student, not a developer.
    var error: String?

    /// Nothing sent, nothing waiting. The web's `IDLE_STATUS`.
    static let idle = SyncStatus(state: .saved, lastSyncedAt: nil, pending: 0, error: nil)
}

// MARK: - Trying again

/// How long to wait before each retry of a failed send, in milliseconds.
/// Starts fast (most failures are a dropped connection already back) and
/// tops out at half a minute. The web's `RETRY_DELAYS_MS`.
let RETRY_DELAYS_MS = [1_000, 3_000, 8_000, 20_000, 30_000]

/// The wait before retry number `attempt` (0 is the first), staying at the
/// last delay after that. A negative attempt counts as the first; the web
/// would return nothing there, and nothing calls it that way.
func retryDelay(_ attempt: Int) -> Int {
    RETRY_DELAYS_MS[min(max(attempt, 0), RETRY_DELAYS_MS.count - 1)]
}

// MARK: - The words

/// Short label for the status chip. The web's `syncLabel`.
func syncLabel(_ status: SyncStatus) -> String {
    switch status.state {
    case .saved:
        return "Saved on this device"
    case .syncing:
        return "Syncing\u{2026}"
    case .synced:
        return "Synced"
    case .offline:
        return status.pending > 0
            ? "Offline, \(status.pending) change\(status.pending == 1 ? "" : "s") waiting"
            : "Offline"
    case .error:
        return status.error ?? "Sync problem"
    }
}

/// The longer line for Settings: where the data actually is in each state.
/// The web's `syncDetail`. `now` is a parameter so tests can fix the clock.
func syncDetail(_ status: SyncStatus, now: Date = Date()) -> String {
    switch status.state {
    case .saved:
        return status.pending > 0
            ? "Your changes are on this device. They'll go to the cloud when you're signed in and online."
            : "Your work is saved on this device."
    case .syncing:
        return "Sending your latest changes\u{2026}"
    case .synced:
        if let at = status.lastSyncedAt {
            return "Everything is backed up. Last synced \(relativeTime(at, now: now))."
        }
        return "Everything is backed up."
    case .offline:
        if let at = status.lastSyncedAt {
            return "You're offline. Changes are safe on this device and will sync automatically. Last synced \(relativeTime(at, now: now))."
        }
        return "You're offline. Changes are safe on this device and will sync when you reconnect."
    case .error:
        return "\(status.error ?? "Something went wrong syncing.") Your work is still saved on this device."
    }
}

/// "just now", "6 minutes ago", "yesterday": enough precision to be useful.
/// The web's `relativeTime`. `at` is in milliseconds since 1970.
///
/// JavaScript's `Math.round` and Swift's `rounded()` agree on every number
/// here (they differ only on negative halves, and the gap is never negative
/// after the `max(0, ...)`). From 30 days on the web prints the browser's
/// date; this prints the phone's own short date, so that one line is
/// worded by the device on purpose (D-91).
func relativeTime(_ at: Double, now: Date = Date()) -> String {
    // The web works in whole milliseconds, so round the clock to match.
    let nowMS = (now.timeIntervalSince1970 * 1000).rounded()
    let secs = max(0, ((nowMS - at) / 1000).rounded())
    if secs < 45 { return "just now" }
    let mins = Int((secs / 60).rounded())
    if mins < 60 { return "\(mins) minute\(mins == 1 ? "" : "s") ago" }
    let hours = Int((Double(mins) / 60).rounded())
    if hours < 24 { return "\(hours) hour\(hours == 1 ? "" : "s") ago" }
    let days = Int((Double(hours) / 24).rounded())
    if days == 1 { return "yesterday" }
    if days < 30 { return "\(days) days ago" }
    let date = Date(timeIntervalSince1970: at / 1000)
    return date.formatted(date: .numeric, time: .omitted)
}

// MARK: - Errors

/// Is this the kind of failure a fresh sign-in token can fix? A JWT or 401
/// from Supabase almost never means the account is gone: Clerk can mint a new
/// token quietly, so the app refreshes and retries instead of asking the
/// student to sign in. The web's `isAuthError`. Takes the error's message
/// text (the web digs the message out of whatever it was handed).
func isAuthError(_ message: String) -> Bool {
    let lower = message.lowercased()
    return lower.contains("jwt") || lower.contains("401") || lower.contains("unauthor")
}

/// Turns a failure's message into something a student can act on. Most sync
/// failures aren't the student's fault and aren't dressed up as one; the
/// actionable ones (an expired session, no room left) get their own words.
/// The web's `describeSyncError`.
func describeSyncError(_ message: String) -> String {
    let lower = message.lowercased()
    if lower.contains("jwt") || lower.contains("401") || lower.contains("unauthor") {
        return "Your session expired. Sign in again to keep syncing."
    }
    if lower.contains("quota") || lower.contains("storage") || lower.contains("full") {
        return "There's no room left to save more. Free some space and try again."
    }
    if lower.contains("row-level security") || lower.contains("policy") {
        return "This account isn't allowed to save that. Sign out and back in."
    }
    if lower.contains("fetch") || lower.contains("network") {
        return "Couldn't reach the server."
    }
    return "Couldn't save your latest changes to the cloud."
}
