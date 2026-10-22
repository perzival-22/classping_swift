//
//  File:    ~/ClassPing/Sources/ClassPing/Sync/SyncEngine.swift
//  Phase:   14cd (sign-in and sync)
//  Ports:   the two sync effects of lib/store.tsx: pull once on sign-in, then
//           a debounced flush 800 ms after any change (with the token refresh
//           on an expired session and the retry waits of lib/sync.ts); plus
//           the first-sync guards of D-90 and D-97, which the web doesn't have
//
//  Summary: Decides when to pull and when to push, and what the status chip
//           says. The first time an account syncs on this phone nothing is
//           sent or changed until you've seen the review and said go. After
//           that, every change saves on the phone first and goes to the
//           server a moment later; coming back to the app pulls what other
//           devices changed.
//

import Foundation

/// Where sync stands for the signed-in account.
enum SyncPhase: Equatable {
    /// Nobody is signed in: the planner lives on this phone only.
    case signedOut
    /// Signed in, working out what a first sync would do.
    case preparing
    /// Signed in for the first time on this phone: the review is ready and
    /// nothing has been sent or changed (D-90).
    case review(SyncReview)
    /// Syncing normally: pulls and pushes as things change.
    case live
}

/// Runs sync for the app. One per app, made at launch beside the store.
@MainActor @Observable
final class SyncEngine {
    /// The planner being synced.
    let store: Store
    /// Who is signed in.
    let account = Account()

    /// Where sync stands (see `SyncPhase`).
    var phase: SyncPhase = .signedOut
    /// What the chip says: 14a's states, labels and retry rules.
    var status = SyncStatus(state: .saved, lastSyncedAt: nil, pending: 0, error: nil)

    /// What the server last confirmed, for the signed-in account.
    private var snapshot: SyncSnapshot? = nil
    /// The road to the server for the signed-in account.
    private var transport: SupabaseTransport? = nil
    /// The account the snapshot and transport belong to.
    private var syncingFor: String? = nil
    /// The waiting push, so a newer change can restart the wait.
    private var flushTask: Task<Void, Never>? = nil
    /// How many expired-token failures in a row were fixed quietly.
    private var authRetries = 0
    /// How many ordinary failures in a row, for 14a's `retryDelay`.
    private var retryAttempt = 0
    /// True while a pull or push is talking to the server.
    private var busy = false

    /// The web's AUTH_RETRY_LIMIT: three quiet token refreshes before asking
    /// you to sign in again.
    private let authRetryLimit = 3

    init(store: Store) {
        self.store = store
    }

    // MARK: Signing in and out

    /// Called when the signed-in account may have changed (launch, sign-in,
    /// sign-out). Starts or stops sync to match.
    func accountChanged() async {
        guard let userID = account.userID else {
            phase = .signedOut
            snapshot = nil
            transport = nil
            syncingFor = nil
            status = SyncStatus(state: .saved, lastSyncedAt: nil, pending: 0, error: nil)
            return
        }
        guard userID != syncingFor else { return }
        syncingFor = userID
        transport = SupabaseTransport(userID: userID)
        snapshot = Store.loadSnapshot(userID: userID)
        authRetries = 0
        retryAttempt = 0
        if snapshot == nil {
            await prepareReview()
        } else {
            phase = .live
            await pullAndPush()
        }
    }

    // MARK: The first sync (D-90, D-97)

    /// Pulls and works out what a first sync would do, changing nothing.
    func prepareReview() async {
        guard let transport, let userID = syncingFor else { return }
        phase = .preparing
        status.state = .syncing
        switch await transport.pull() {
        case .success(let pull):
            phase = .review(store.reviewPull(pull, snapshot: nil, userID: userID))
            status.state = .saved
            status.error = nil
        case .failure(let failure):
            phase = .review(SyncReview())
            fail(failure)
        }
    }

    /// You said go: pulls again (the planner may have changed while you read
    /// the review), merges it in, sends what this phone adds, and from then
    /// on syncs normally.
    func confirmFirstSync() async {
        guard let transport, let userID = syncingFor else { return }
        status.state = .syncing
        switch await transport.pull() {
        case .failure(let failure):
            fail(failure)
        case .success(let pull):
            let merged = store.applyPull(pull, snapshot: nil, userID: userID, now: .now)
            snapshot = merged
            Store.saveSnapshot(merged, userID: userID)
            phase = .live
            await transport.setTimeZone(TimeZone.autoupdatingCurrent.identifier)
            await flush()
        }
    }

    /// Not now: signs out and leaves both sides exactly as they were.
    func declineFirstSync() async {
        await account.signOut()
        await accountChanged()
    }

    // MARK: Normal sync

    /// Pulls what changed elsewhere, merges it in, then sends what's waiting.
    /// Runs when sync starts and each time the app comes back to the screen.
    func pullAndPush() async {
        guard phase == .live, !busy, let transport, let userID = syncingFor else { return }
        busy = true
        status.state = .syncing
        let pulled = await transport.pull()
        busy = false
        switch pulled {
        case .failure(let failure):
            if await healedToken(failure) { await pullAndPush() } else { fail(failure) }
        case .success(let pull):
            let merged = store.applyPull(pull, snapshot: snapshot, userID: userID, now: .now)
            snapshot = merged
            Store.saveSnapshot(merged, userID: userID)
            authRetries = 0
            await transport.setTimeZone(TimeZone.autoupdatingCurrent.identifier)
            await flush()
        }
    }

    /// Something in the planner changed: wait 800 ms (a newer change restarts
    /// the wait), then send. The web's debounced flush.
    func plannerChanged() {
        guard phase == .live, let userID = syncingFor, let snapshot else { return }
        status.pending = store.pendingPush(snapshot: snapshot, userID: userID).count
        if status.pending > 0, status.state != .error { status.state = .saved }
        flushTask?.cancel()
        flushTask = Task {
            try? await Task.sleep(for: .milliseconds(800))
            guard !Task.isCancelled else { return }
            await flush()
        }
    }

    /// Sends what's waiting, if anything. "Synced" only once the server has
    /// confirmed every step.
    func flush() async {
        guard phase == .live, !busy, let transport, let userID = syncingFor, let snapshot else { return }
        let pending = store.pendingPush(snapshot: snapshot, userID: userID)
        status.pending = pending.count
        guard pending.count > 0 else {
            if status.state != .error { status.state = .synced }
            status.lastSyncedAt = snapshot.lastSyncedAt ?? status.lastSyncedAt
            return
        }
        busy = true
        status.state = .syncing
        let outcome = await store.push(pending, snapshot: snapshot, via: transport, now: .now)
        busy = false
        // Whatever got through is remembered, success or not.
        self.snapshot = outcome.snapshot
        Store.saveSnapshot(outcome.snapshot, userID: userID)
        if let failure = outcome.failure {
            if await healedToken(failure) { await flush() } else { fail(failure) }
            return
        }
        authRetries = 0
        retryAttempt = 0
        status = SyncStatus(state: .synced, lastSyncedAt: outcome.snapshot.lastSyncedAt, pending: 0, error: nil)
    }

    // MARK: Failures

    /// An expired token is the app's to fix: ask Clerk for a fresh one and
    /// try again, up to three times in a row. True when a retry is worth it.
    private func healedToken(_ failure: SyncFailure) async -> Bool {
        guard !failure.offline, isAuthError(failure.message), authRetries < authRetryLimit else { return false }
        authRetries += 1
        return await Account.sessionToken(skipCache: true) != nil
    }

    /// Shows the failure in 14a's words and tries again after 14a's wait.
    private func fail(_ failure: SyncFailure) {
        status.state = failure.offline ? .offline : .error
        status.error = failure.offline ? nil : describeSyncError(failure.message)
        let wait = retryDelay(retryAttempt)
        retryAttempt += 1
        flushTask?.cancel()
        flushTask = Task {
            try? await Task.sleep(for: .milliseconds(wait))
            guard !Task.isCancelled else { return }
            if phase == .live { await pullAndPush() }
        }
    }
}
