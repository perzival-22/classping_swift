//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/Columns.swift
//  Phase:   14a (the sync rules, before any network)
//  Ports:   lib/supabase/columns.ts (`TABLE_COLUMNS`, `TZ_COLUMNS`,
//           `ColumnContractError`, `scopeRows`, `scopeRow`, `pickColumns`);
//           its tests are lib/supabase/columns.test.ts
//
//  Summary: The columns this app writes, per table, written down once. When
//           several rows go to the server in one batch, the server writes
//           every column any row names, and a row that left one out gets it
//           blanked. So every batch is trimmed to the same columns first, and
//           a column some row lacks is left out of the whole batch: "don't
//           touch it" is always safer than "erase it".
//

import Foundation

// MARK: - The tables and their columns

/// The tables the app writes. The raw text is the table's name on the server.
enum ScopedTable: String, CaseIterable, Sendable {
    case classes
    case tasks
    case grades
    case notes
    case taskPlans = "task_plans"
    case studySessions = "study_sessions"
    case profiles
    case gameState = "game_state"

    /// The columns this app owns in the table, in the web's order. `rev` and
    /// `updated_at` are never here: the database owns those. Nor is
    /// `profiles.tz`, which goes in its own two-column write (`TZ_COLUMNS`).
    /// The web's `TABLE_COLUMNS`; the tests check every list against it.
    var columns: [String] {
        switch self {
        case .classes:
            return ["id", "user_id", "name", "short", "color", "days",
                    "additional_meetings", "start_min", "end_min", "remind_before",
                    "alarm", "extra_reminders", "credits", "room", "instructor",
                    "notes", "term", "archived", "goal", "source_feed", "source_uid",
                    "source_hash", "deleted_at"]
        case .tasks:
            return ["id", "user_id", "class_id", "title", "due", "due_time",
                    "reminder", "done", "kind", "notes", "subtasks", "remind_leads",
                    "snoozed_until", "repeat_rule", "repeat_until",
                    "recurrence_parent_id", "source_feed", "source_uid",
                    "source_hash", "deleted_at"]
        case .grades:
            return ["id", "user_id", "class_id", "title", "score", "max", "weight",
                    "date", "kind", "deleted_at"]
        case .notes:
            return ["id", "user_id", "class_id", "date", "title", "body", "task_id",
                    "deleted_at"]
        case .taskPlans:
            return ["id", "user_id", "task_id", "date", "priority"]
        case .studySessions:
            return ["id", "user_id", "task_id", "class_id", "minutes",
                    "completed_at", "mode"]
        case .profiles:
            return ["user_id", "username", "avatar_url", "theme", "accent", "style",
                    "post_class_nudge", "quiet_start", "quiet_end", "finals_date",
                    "grade_scale", "term_start", "term_end", "term_name",
                    "term_setup_prompted", "import_feeds", "custom_scale", "quotes"]
        case .gameState:
            return ["user_id", "data"]
        }
    }

    /// Columns a row can't go without. With no `id` the server can't match the
    /// row, and with no `user_id` it refuses it, so these two are the cases
    /// where quietly leaving the column out isn't safe. The web's `REQUIRED`.
    var required: [String] {
        switch self {
        case .profiles, .gameState:
            return ["user_id"]
        default:
            return ["id", "user_id"]
        }
    }
}

/// The phone's time zone write: these two columns and nothing else, so it
/// never touches the rest of the profile. The web's `TZ_COLUMNS`.
let TZ_COLUMNS = ["user_id", "tz"]

// MARK: - Trimming a batch

/// Why a batch couldn't be trimmed. The web throws a `ColumnContractError`;
/// here it comes back inside a `Result`, as in 11a, so no `do`/`catch`.
enum ColumnContractError: Error, Equatable, Sendable {
    /// A row is missing `column`, which can't safely be left out.
    case missingRequired(table: ScopedTable, column: String)

    /// The web's message, word for word.
    var message: String {
        switch self {
        case .missingRequired(let table, let column):
            return "\(table.rawValue): a row is missing \(column), which is not safe to omit"
        }
    }
}

/// One row on its way to the server: column name to value. A column that
/// isn't in the dictionary is the web's `undefined` (leave it alone); a
/// `.null` value is the web's `null` (write an empty value). That difference
/// is how a restore clears `deleted_at`.
typealias ServerRow = [String: JSONValue]

/// Trims a batch to the columns this app owns. Every row comes back with the
/// same columns; anything undeclared is dropped; a declared column that any
/// row is missing is dropped from every row (so the server keeps its value).
/// A row without a required column fails the whole batch. An empty batch
/// stays empty. The web's `scopeRows`.
///
/// One difference: a Swift dictionary has no order, so the rows don't keep
/// the declared column order. Only the set of columns matters to the server.
func scopeRows(_ table: ScopedTable, _ rows: [ServerRow]) -> Result<[ServerRow], ColumnContractError> {
    if rows.isEmpty { return .success([]) }

    // A required column that's missing or null fails the batch. The web checks
    // each required column across every row in this order, so the error names
    // the same column the web's would.
    for column in table.required {
        let missing = rows.contains { row in
            row[column] == nil || row[column] == JSONValue.null
        }
        if missing {
            return .failure(.missingRequired(table: table, column: column))
        }
    }

    // The columns every row actually carries (a `.null` counts as carried).
    let effective = table.columns.filter { column in
        rows.allSatisfy { $0[column] != nil }
    }

    // Each row keeps exactly those columns.
    let scoped = rows.map { row in
        var out: ServerRow = [:]
        for column in effective {
            out[column] = row[column]
        }
        return out
    }
    return .success(scoped)
}

/// One row, same rules. For the two one-row tables (profiles, game_state).
/// The web's `scopeRow`.
func scopeRow(_ table: ScopedTable, _ row: ServerRow) -> Result<ServerRow, ColumnContractError> {
    scopeRows(table, [row]).map { $0.first ?? [:] }
}

/// Picks only the given columns from one row, for a write that touches a
/// few columns on purpose (the time zone write). A column the row doesn't
/// have is left out rather than sent empty. The web's `pickColumns`.
func pickColumns(_ row: ServerRow, _ columns: [String]) -> ServerRow {
    var out: ServerRow = [:]
    for column in columns {
        if let value = row[column] {
            out[column] = value
        }
    }
    return out
}
