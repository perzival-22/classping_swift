// WebValues14a.swift: what the web's own functions answered for Phase 14a.
// Written by docs/ios/.scratch/p14a/gen.ts (node 24, lib/merge.ts, lib/sync.ts,
// lib/supabase/columns.ts, run unchanged). Kelvin does not type this file.
// Every value here is marked "web:" in the tests that read it.

/// `hashRow(input)` on the web, input first.
let WEB_HASHES: [(input: String, hash: String)] = [
    ("", "wvjl67o803"),
    ("hello", "19jqrdkps12"),
    ("Essay 1", "2fiuo6ti7w4"),
    ("Essay 2", "1rxuaxphqo2"),
    ("a", "262p94epp1d"),
    ("ab", "xb319mxp3m"),
    ("{\"id\":\"a\",\"title\":\"Essay\"}", "2fs2f0461fd"),
    ("{\"id\":\"a\",\"title\":\"Essay, final\"}", "58bjc3wj6l"),
    ("caf\u{E9}", "1440vtls1if"),
    ("\u{1F4DA} notes", "25g1vwaqplc"),
    ("\u{1F600}\u{1F600}\u{1F600}", "112ymwbwbvl"),
    ("line one\nline two\r\nline three", "23wcckvth9n"),
    ("\u{FEFF}bom first", "1j3ie1rdx5v"),
    ("ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ", "26s1l0ggkbl"),
    ("\u{0}nul", "27c8kldhgzp"),
    ("\u{FF}\u{100}\u{101}\u{7FF}\u{800}\u{FFFF}", "6x5agd6jc6"),
]

/// `retryDelay(attempt)` on the web, for the attempts 0 to 7.
let WEB_RETRY_DELAYS: [Int] = [1000, 3000, 8000, 20000, 30000, 30000, 30000, 30000]

/// The moment all the status text below was worked out at (ms).
let WEB_NOW_MS: Double = 1790000000000

/// `relativeTime(NOW - ago)` on the web, `ago` in milliseconds.
let WEB_RELATIVE: [(agoMS: Double, text: String)] = [
    (-5000, "just now"),
    (0, "just now"),
    (1000, "just now"),
    (44000, "just now"),
    (44499, "just now"),
    (44500, "1 minute ago"),
    (45000, "1 minute ago"),
    (59000, "1 minute ago"),
    (89000, "1 minute ago"),
    (90000, "2 minutes ago"),
    (119000, "2 minutes ago"),
    (3599000, "1 hour ago"),
    (3600000, "1 hour ago"),
    (5399000, "2 hours ago"),
    (5400000, "2 hours ago"),
    (86399000, "yesterday"),
    (86400000, "yesterday"),
    (129599000, "2 days ago"),
    (129600000, "2 days ago"),
    (172800000, "2 days ago"),
    (2500000000, "29 days ago"),
]

/// One status as the web holds it, and the label and detail it shows.
struct WebStatusCase {
    let state: String
    let lastSyncedAt: Double?
    let pending: Int
    let error: String?
    let label: String
    let detail: String
}

let WEB_STATUS_CASES: [WebStatusCase] = [
    WebStatusCase(
        state: "saved",
        lastSyncedAt: nil,
        pending: 0,
        error: nil,
        label: "Saved on this device",
        detail: "Your work is saved on this device."),
    WebStatusCase(
        state: "saved",
        lastSyncedAt: nil,
        pending: 3,
        error: nil,
        label: "Saved on this device",
        detail: "Your changes are on this device. They'll go to the cloud when you're signed in and online."),
    WebStatusCase(
        state: "saved",
        lastSyncedAt: 1789999400000,
        pending: 1,
        error: nil,
        label: "Saved on this device",
        detail: "Your changes are on this device. They'll go to the cloud when you're signed in and online."),
    WebStatusCase(
        state: "syncing",
        lastSyncedAt: nil,
        pending: 2,
        error: nil,
        label: "Syncing\u{2026}",
        detail: "Sending your latest changes\u{2026}"),
    WebStatusCase(
        state: "synced",
        lastSyncedAt: nil,
        pending: 0,
        error: nil,
        label: "Synced",
        detail: "Everything is backed up."),
    WebStatusCase(
        state: "synced",
        lastSyncedAt: 1789999970000,
        pending: 0,
        error: nil,
        label: "Synced",
        detail: "Everything is backed up. Last synced just now."),
    WebStatusCase(
        state: "synced",
        lastSyncedAt: 1789992800000,
        pending: 0,
        error: nil,
        label: "Synced",
        detail: "Everything is backed up. Last synced 2 hours ago."),
    WebStatusCase(
        state: "offline",
        lastSyncedAt: nil,
        pending: 0,
        error: nil,
        label: "Offline",
        detail: "You're offline. Changes are safe on this device and will sync when you reconnect."),
    WebStatusCase(
        state: "offline",
        lastSyncedAt: nil,
        pending: 1,
        error: nil,
        label: "Offline, 1 change waiting",
        detail: "You're offline. Changes are safe on this device and will sync when you reconnect."),
    WebStatusCase(
        state: "offline",
        lastSyncedAt: 1789913600000,
        pending: 4,
        error: nil,
        label: "Offline, 4 changes waiting",
        detail: "You're offline. Changes are safe on this device and will sync automatically. Last synced yesterday."),
    WebStatusCase(
        state: "offline",
        lastSyncedAt: 1789999700000,
        pending: 0,
        error: nil,
        label: "Offline",
        detail: "You're offline. Changes are safe on this device and will sync automatically. Last synced 5 minutes ago."),
    WebStatusCase(
        state: "error",
        lastSyncedAt: nil,
        pending: 0,
        error: nil,
        label: "Sync problem",
        detail: "Something went wrong syncing. Your work is still saved on this device."),
    WebStatusCase(
        state: "error",
        lastSyncedAt: nil,
        pending: 2,
        error: "Couldn't reach the server.",
        label: "Couldn't reach the server.",
        detail: "Couldn't reach the server. Your work is still saved on this device."),
    WebStatusCase(
        state: "error",
        lastSyncedAt: 1789999940000,
        pending: 2,
        error: "",
        label: "",
        detail: " Your work is still saved on this device."),
]

/// `describeSyncError(message)` and `isAuthError(message)` on the web.
let WEB_ERRORS: [(message: String, text: String, auth: Bool)] = [
    ("", "Couldn't save your latest changes to the cloud.", false),
    ("JWT expired", "Your session expired. Sign in again to keep syncing.", true),
    ("jwt malformed", "Your session expired. Sign in again to keep syncing.", true),
    ("Request failed with status 401", "Your session expired. Sign in again to keep syncing.", true),
    ("Unauthorized", "Your session expired. Sign in again to keep syncing.", true),
    ("unauthorised request", "Your session expired. Sign in again to keep syncing.", true),
    ("quota exceeded", "There's no room left to save more. Free some space and try again.", false),
    ("Storage is full", "There's no room left to save more. Free some space and try again.", false),
    ("disk full", "There's no room left to save more. Free some space and try again.", false),
    ("new row violates row-level security policy for table \"tasks\"", "This account isn't allowed to save that. Sign out and back in.", false),
    ("policy check failed", "This account isn't allowed to save that. Sign out and back in.", false),
    ("TypeError: Failed to fetch", "Couldn't reach the server.", false),
    ("Network request failed", "Couldn't reach the server.", false),
    ("something else entirely", "Couldn't save your latest changes to the cloud.", false),
    ("401 and the disk is full", "Your session expired. Sign in again to keep syncing.", true),
    ("full of jwt", "Your session expired. Sign in again to keep syncing.", true),
]

/// `TABLE_COLUMNS` on the web, by table name, in the web's order.
let WEB_TABLE_COLUMNS: [String: [String]] = [
    "classes": ["id", "user_id", "name", "short", "color", "days", "additional_meetings", "start_min", "end_min", "remind_before", "alarm", "extra_reminders", "credits", "room", "instructor", "notes", "term", "archived", "goal", "source_feed", "source_uid", "source_hash", "deleted_at"],
    "tasks": ["id", "user_id", "class_id", "title", "due", "due_time", "reminder", "done", "kind", "notes", "subtasks", "remind_leads", "snoozed_until", "repeat_rule", "repeat_until", "recurrence_parent_id", "source_feed", "source_uid", "source_hash", "deleted_at"],
    "grades": ["id", "user_id", "class_id", "title", "score", "max", "weight", "date", "kind", "deleted_at"],
    "notes": ["id", "user_id", "class_id", "date", "title", "body", "task_id", "deleted_at"],
    "task_plans": ["id", "user_id", "task_id", "date", "priority"],
    "study_sessions": ["id", "user_id", "task_id", "class_id", "minutes", "completed_at", "mode"],
    "profiles": ["user_id", "username", "avatar_url", "theme", "accent", "style", "post_class_nudge", "quiet_start", "quiet_end", "finals_date", "grade_scale", "term_start", "term_end", "term_name", "term_setup_prompted", "import_feeds", "custom_scale", "quotes"],
    "game_state": ["user_id", "data"],
]

/// `TZ_COLUMNS` on the web.
let WEB_TZ_COLUMNS: [String] = ["user_id", "tz"]
