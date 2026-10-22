//
//  File:    ~/ClassPing/Sources/ClassPing/Sync/SupabaseTransport.swift
//  Phase:   14cd (sign-in and sync)
//  Ports:   lib/supabase/client.ts (`createClient` with Clerk's token as
//           `accessToken`) and the Supabase calls in lib/store.tsx's sync:
//           the eight selects, `upsert`, `delete().in("id", …)` and the
//           `{ user_id, tz }` upsert
//
//  Summary: The real road to the server, for `Store+Sync.swift`. Every request
//           carries the signed-in user's Clerk token, which Supabase checks,
//           and row-level security keeps each account to its own rows. Each
//           call hands back a `Result` with the server's or the network's
//           words when it fails.
//

import Foundation
import Supabase

/// Talks to Supabase for one signed-in account. `final class` because it
/// holds one long-lived client; `Sendable` (through `SyncTransport`) because
/// sync work runs off the main thread. All of its stored properties are
/// constants of Sendable types, which is what lets Swift accept that.
final class SupabaseTransport: SyncTransport {
    /// The account whose rows these are.
    let userID: String
    /// supabase-swift's client, built once.
    private let client: SupabaseClient

    /// A client whose every request asks Clerk for the current token, as the
    /// web's `accessToken: async () => (await getToken()) ?? null`.
    init(userID: String) {
        self.userID = userID
        client = SupabaseClient(
            supabaseURL: SyncConfig.supabaseURL,
            supabaseKey: SyncConfig.supabaseAnonKey,
            options: SupabaseClientOptions(auth: .init(accessToken: { await Account.sessionToken() }))
        )
    }

    /// Reads every table, one after another. The web asks for all eight at
    /// once; one by one is slower by a second at most and simpler to follow.
    func pull() async -> Result<ServerPull, SyncFailure> {
        let client = self.client
        // `Task { … }.result` keeps a thrown error as a `Result` (see Account).
        let outcome = await Task { () async throws -> ServerPull in
            var pull = ServerPull()
            for table in LIST_TABLES {
                let rows: [ServerRow] = try await client.from(table.rawValue).select().execute().value
                pull.lists[table] = rows
            }
            let profiles: [ServerRow] = try await client.from("profiles").select().limit(1).execute().value
            pull.profile = profiles.first
            let games: [ServerRow] = try await client.from("game_state").select().limit(1).execute().value
            pull.game = games.first
            return pull
        }.result
        return outcome.mapError(Self.failure)
    }

    /// Writes rows. The profile and progress have one row per account, keyed
    /// by `user_id`; every other table is keyed by `id`.
    func upsert(_ table: ScopedTable, _ rows: [ServerRow]) async -> Result<Int, SyncFailure> {
        let client = self.client
        let key = (table == .profiles || table == .gameState) ? "user_id" : "id"
        let outcome = await Task { () async throws -> Int in
            _ = try await client.from(table.rawValue)
                .upsert(rows, onConflict: key, returning: .minimal)
                .execute()
            return rows.count
        }.result
        return outcome.mapError(Self.failure)
    }

    /// Deletes rows by id. Row-level security limits it to this account's rows.
    func delete(_ table: ScopedTable, ids: [String]) async -> Result<Int, SyncFailure> {
        let client = self.client
        let outcome = await Task { () async throws -> Int in
            _ = try await client.from(table.rawValue)
                .delete(returning: .minimal)
                .in("id", values: ids)
                .execute()
            return ids.count
        }.result
        return outcome.mapError(Self.failure)
    }

    /// Tells the server this phone's time zone, for the web's reminder emails,
    /// in its own two-column write so it never touches the rest of the profile
    /// (14a's `TZ_COLUMNS`). Best effort, as on the web: a failure is ignored.
    func setTimeZone(_ identifier: String) async {
        let client = self.client
        let row: ServerRow = pickColumns(["user_id": .string(userID), "tz": .string(identifier)], TZ_COLUMNS)
        _ = await Task {
            _ = try await client.from("profiles").upsert(row, onConflict: "user_id", returning: .minimal).execute()
        }.result
    }

    /// Puts any error into words `isAuthError` and `describeSyncError` (14a)
    /// understand, and says whether the phone is simply offline. `as?` asks
    /// "is this error that kind?" and gives nil if it isn't.
    private static func failure(_ error: any Error) -> SyncFailure {
        if let network = error as? URLError {
            let offline: Set<URLError.Code> = [.notConnectedToInternet, .networkConnectionLost,
                                               .cannotFindHost, .cannotConnectToHost,
                                               .timedOut, .dataNotAllowed]
            return SyncFailure(message: "network: \(network.localizedDescription)",
                               offline: offline.contains(network.code))
        }
        if let server = error as? PostgrestError {
            return SyncFailure(message: [server.code, server.message].compactMap { $0 }.joined(separator: " "))
        }
        if let http = error as? HTTPError {
            let body = String(decoding: http.data, as: UTF8.self).prefix(200)
            return SyncFailure(message: "\(http.response.statusCode) \(body)")
        }
        return SyncFailure(message: error.localizedDescription)
    }
}
