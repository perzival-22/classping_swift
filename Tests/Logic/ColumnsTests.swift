// ColumnsTests.swift: the Swift twin of lib/supabase/columns.test.ts. The
// "mappers and column lists agree" cases need the row mapping, so they arrive
// with it in Phase 14b; here every list is checked against the web's own
// TABLE_COLUMNS instead (WebValues14a.swift, "web:").
// Run: tools/logic-test.sh. Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

private let UID = "user_123"

/// A task row with every column the app owns, standing in for the web's
/// `taskToRow(aTask, UID)` until 14b ports the mapper. `deleted_at` is an
/// explicit null, as the web's mapper writes it.
private func taskRow(_ id: String = "t1") -> ServerRow {
    var row: ServerRow = [:]
    for column in ScopedTable.tasks.columns {
        row[column] = .null
    }
    row["id"] = .string(id)
    row["user_id"] = .string(UID)
    row["class_id"] = .string("c1")
    row["title"] = .string("Essay")
    row["due"] = .string("2026-09-10")
    row["due_time"] = .string("23:30")
    row["reminder"] = .bool(true)
    row["done"] = .bool(false)
    return row
}

/// A row without one column: a client that has never heard of it.
private func omit(_ row: ServerRow, _ column: String) -> ServerRow {
    var out = row
    out[column] = nil
    return out
}

/// The scoped rows, or none if the batch was refused.
private func rows(_ result: Result<[ServerRow], ColumnContractError>) -> [ServerRow] {
    (try? result.get()) ?? []
}

@Suite struct ColumnsTests {
    // MARK: the lists (web: TABLE_COLUMNS and TZ_COLUMNS)

    @Test func everyTableMatchesTheWebInOrder() {
        #expect(Set(ScopedTable.allCases.map(\.rawValue)) == Set(WEB_TABLE_COLUMNS.keys))
        for table in ScopedTable.allCases {
            #expect(table.columns == WEB_TABLE_COLUMNS[table.rawValue], "table: \(table.rawValue)")
        }
    }

    @Test func neverDeclaresAColumnTheDatabaseOwns() {
        for table in ScopedTable.allCases {
            #expect(!table.columns.contains("rev"))
            #expect(!table.columns.contains("updated_at"))
        }
    }

    @Test func keepsTzOutOfTheProfileAndInItsOwnWrite() {
        #expect(!ScopedTable.profiles.columns.contains("tz"))
        #expect(TZ_COLUMNS == ["user_id", "tz"])
        #expect(TZ_COLUMNS == WEB_TZ_COLUMNS)
    }

    @Test func declaresNoColumnTwice() {
        for table in ScopedTable.allCases {
            #expect(Set(table.columns).count == table.columns.count)
        }
    }

    // MARK: scoping a batch (the web's cases)

    @Test func givesEveryRowInABatchTheSameKeys() {
        var second = taskRow("t2")
        second["kind"] = .string("exam")
        second["remind_leads"] = .array([.number(4320)])
        let scoped = rows(scopeRows(.tasks, [taskRow(), second]))
        #expect(scoped.count == 2)
        #expect(Set(scoped[0].keys) == Set(scoped[1].keys))
        #expect(Set(scoped[0].keys) == Set(ScopedTable.tasks.columns))
    }

    @Test func dropsAColumnNoRowCarriesRatherThanNullingIt() {
        let legacy = [omit(taskRow(), "remind_leads"), omit(taskRow("t2"), "remind_leads")]
        let scoped = rows(scopeRows(.tasks, legacy))
        #expect(scoped.count == 2)
        #expect(scoped[0]["remind_leads"] == nil)
        #expect(scoped[1]["remind_leads"] == nil)
    }

    @Test func dropsItFromTheWholeBatchWhenOnlySomeRowsCarryIt() {
        let mixed = [taskRow(), omit(taskRow("t2"), "remind_leads")]
        let scoped = rows(scopeRows(.tasks, mixed))
        #expect(scoped.count == 2)
        #expect(scoped[0]["remind_leads"] == nil)
        #expect(scoped[1]["remind_leads"] == nil)
        #expect(Set(scoped[0].keys) == Set(scoped[1].keys))
    }

    @Test func dropsAColumnThisAppDoesNotOwn() {
        var stranger = taskRow()
        stranger["invented_by_a_fork"] = .number(1)
        stranger["rev"] = .number(7)
        let scoped = rows(scopeRows(.tasks, [stranger]))
        #expect(scoped.count == 1)
        #expect(scoped.first?["invented_by_a_fork"] == nil)
        #expect(scoped.first?["rev"] == nil)
    }

    @Test func keepsAnExplicitNullWhichIsHowARestoreClearsDeletedAt() {
        let scoped = rows(scopeRows(.tasks, [taskRow()]))
        #expect(scoped.first?["deleted_at"] == .null)
    }

    @Test func refusesARowWithNoIdOrNoUserId() {
        #expect(scopeRows(.tasks, [omit(taskRow(), "id")])
                == .failure(.missingRequired(table: .tasks, column: "id")))
        #expect(scopeRows(.tasks, [omit(taskRow(), "user_id")])
                == .failure(.missingRequired(table: .tasks, column: "user_id")))
    }

    /// The web's check treats null like missing for the required two.
    @Test func refusesANullUserId() {
        var row = taskRow()
        row["user_id"] = .null
        #expect(scopeRows(.tasks, [taskRow("t0"), row])
                == .failure(.missingRequired(table: .tasks, column: "user_id")))
    }

    /// The web checks `id` before `user_id`, so a row missing both names `id`.
    @Test func namesTheFirstRequiredColumnInTheWebsOrder() {
        let row = omit(omit(taskRow(), "id"), "user_id")
        let result = scopeRows(.tasks, [row])
        #expect(result == .failure(.missingRequired(table: .tasks, column: "id")))
    }

    /// The web's message, word for word.
    @Test func theErrorMessageIsTheWebs() {
        let error = ColumnContractError.missingRequired(table: .taskPlans, column: "user_id")
        #expect(error.message == "task_plans: a row is missing user_id, which is not safe to omit")
    }

    @Test func sendsNothingForAnEmptyBatch() {
        #expect(scopeRows(.tasks, []) == .success([]))
    }

    @Test func scopesASingletonTheSameWay() {
        var profile: ServerRow = [:]
        for column in ScopedTable.profiles.columns {
            profile[column] = .null
        }
        profile["user_id"] = .string(UID)
        profile["username"] = .string("student")
        profile["tz"] = .string("UTC")
        let scoped = (try? scopeRow(.profiles, profile).get()) ?? [:]
        #expect(scoped["tz"] == nil)
        #expect(Set(scoped.keys) == Set(ScopedTable.profiles.columns))
    }

    // MARK: a deliberately narrow write (the web's two cases)

    @Test func namesOnlyTheColumnsItMeansToTouch() {
        let row: ServerRow = ["user_id": .string(UID), "tz": .string("Africa/Nairobi"), "theme": .string("dark")]
        #expect(pickColumns(row, TZ_COLUMNS) == ["user_id": .string(UID), "tz": .string("Africa/Nairobi")])
    }

    @Test func omitsAMissingValueRatherThanSendingNull() {
        #expect(pickColumns(["user_id": .string(UID)], TZ_COLUMNS) == ["user_id": .string(UID)])
    }
}
