//
//  File:    ~/ClassPing/Sources/ClassPing/Logic/WebCalls.swift
//  Phase:   14e (signed-in server calls)
//  Ports:   what the web's pages send to and read back from its own API
//           routes: app/api/import/ics (ImportCalendar.tsx's `loadFeed`),
//           app/api/avatar (`uploadAvatar` in lib/avatar.ts),
//           app/api/email/prefs (the Email switches in
//           app/settings/page.tsx), app/api/account (`handleDeleteAccount`)
//           and app/api/feedback (components/ReviewCard.tsx)
//
//  Summary: The words and shapes of those five conversations, kept apart
//           from the network so the Linux tests can check them: reading a
//           feed's classes and deadlines out of the server's answer, the
//           email switches, what a delete-account answer means, the review's
//           message, and which answers mean "sign in again".
//           Sync/WebAPI.swift does the actual sending.
//

import Foundation

// MARK: - What came back

/// One answer from classping.space: the HTTP status and the JSON body, if it
/// had one. A status of 0 means the server was never reached (no signal, or
/// the phone gave up waiting).
struct WebReply: Equatable, Sendable {
    var status: Int
    var body: JSONValue? = nil

    /// 200 to 299: it worked.
    var ok: Bool { (200..<300).contains(status) }

    /// The server's own sentence for what went wrong, when it sent one. Most
    /// routes answer `{ error, message }`.
    var message: String? {
        guard let text = body?["message"]?.stringValue?.trimmed, !text.isEmpty else { return nil }
        return text
    }

    /// True when the answer means the server didn't take the sign-in token.
    /// Every route here exists, so a 401, a redirect (Clerk sending a
    /// signed-out caller to the sign-in page) or a 404 (Clerk hiding a
    /// protected route from one) all mean the same thing: ask Clerk for a
    /// fresh token and try once more.
    var tokenRefused: Bool {
        status == 401 || status == 404 || (300..<400).contains(status)
    }
}

/// Said when the server can't be reached at all.
let OFFLINE_MESSAGE = "Couldn't reach the server. Check your connection and try again."

/// Said when the server still refuses the sign-in after a fresh token.
let SIGNED_OUT_MESSAGE = "Your session expired. Sign out and back in, then try again."

// MARK: - A calendar feed

/// The classes and deadlines in the server's answer to `/api/import/ics`.
/// The server runs the web's own `parseIcs` and sends its `ImportResult` as
/// JSON; this reads it back into the phone's `ImportResult`, skipping any
/// piece that isn't the shape it should be. Nil when the answer isn't an
/// import at all.
func importResult(fromServer body: JSONValue?) -> ImportResult? {
    guard let body, body.objectValue != nil,
          let rawClasses = body["classes"]?.arrayValue,
          let rawTasks = body["tasks"]?.arrayValue else { return nil }
    var result = ImportResult()

    // `compactMap` keeps what the closure gives back and drops the nils, so
    // a malformed class is skipped rather than stopping the rest.
    result.classes = rawClasses.compactMap { c in
        guard let name = c["name"]?.stringValue, !name.isEmpty,
              let start = c["start"]?.intValue, let end = c["end"]?.intValue,
              let rawDays = c["days"]?.arrayValue else { return nil }
        let days = rawDays.compactMap(\.intValue).filter { (0...6).contains($0) }
        return ImportedClass(
            name: name,
            short: c["short"]?.stringValue ?? importShortName(name),
            color: c["color"]?.stringValue ?? "indigo",
            days: days, start: start, end: end,
            remindBefore: c["remindBefore"]?.intValue ?? 15,
            alarm: c["alarm"]?.boolValue ?? true,
            room: c["room"]?.stringValue,
            sourceUID: c["sourceUid"]?.stringValue)
    }

    result.tasks = rawTasks.compactMap { t in
        guard let title = t["title"]?.stringValue, !title.isEmpty else { return nil }
        // An exam stays an exam; anything else the server says is an assignment.
        let kind = t["kind"]?.stringValue == "exam" ? "exam" : "assignment"
        return ImportedTask(title: title, due: t["due"]?.stringValue,
                            dueTime: t["dueTime"]?.stringValue, kind: kind,
                            sourceUID: t["sourceUid"]?.stringValue)
    }

    result.skipped = body["skipped"]?.intValue ?? 0
    result.cancelled = (body["cancelled"]?.arrayValue ?? []).compactMap(\.stringValue)
    if let start = body["term"]?["start"]?.stringValue {
        result.term = TermDateSuggestion(start: start, end: body["term"]?["end"]?.stringValue)
    }
    return result
}

/// What to say when a feed couldn't be read: the server's own sentence
/// (`data.message ?? "Couldn't import that calendar."` on the web), or the
/// web's catch-all when the server was never reached.
func feedProblem(_ reply: WebReply) -> String {
    if reply.status == 0 { return "Something went wrong. Check the link and try again." }
    if reply.tokenRefused { return SIGNED_OUT_MESSAGE }
    return reply.message ?? "Couldn't import that calendar."
}

// MARK: - The profile photo

/// The photo's new https address from `/api/avatar`, or nil. On nil the
/// phone keeps the picture it already has inside the profile, as the web's
/// `uploadAvatar` does (no storage set up, a failed upload, no signal).
func uploadedAvatarURL(_ reply: WebReply) -> String? {
    guard reply.ok, let url = reply.body?["url"]?.stringValue, url.hasPrefix("https://") else { return nil }
    return url
}

/// The uploaded photo's address with the moment it was uploaded on the end
/// ("…/avatars/user_1.webp?v=1761134400000"). The server keeps one file per
/// account at the same address, so without this a new photo would save the
/// same text as the old one: the profile wouldn't change, sync would send
/// nothing, and every device would keep showing the old picture (D-105).
func versionedAvatarURL(_ url: String, at moment: Date) -> String {
    let millis = Int64((moment.timeIntervalSince1970 * 1000).rounded(.down))
    return url + (url.contains("?") ? "&" : "?") + "v=\(millis)"
}

// MARK: - Email

/// The five kinds of ClassPing email, each switched on its own, so turning
/// off one doesn't stop the others. In the web's order on screen.
enum EmailStream: String, CaseIterable, Sendable {
    case preClass, postClass, assignmentDue, dailyDigest, weekly

    /// The switch's name, in the web's words.
    var label: String {
        switch self {
        case .preClass: "Before class"
        case .postClass: "After class"
        case .assignmentDue: "Assignment due soon"
        case .dailyDigest: "End-of-day digest"
        case .weekly: "Week ahead"
        }
    }

    /// The line under it.
    var hint: String {
        switch self {
        case .preClass: "A heads-up email before each class starts."
        case .postClass: "A prompt to log anything the class assigned."
        case .assignmentDue: "A day before and an hour before each assignment is due."
        case .dailyDigest: "What's still open, once the school day is done."
        case .weekly: "Sunday evening: your classes and what's due this week."
        }
    }
}

/// Your email settings, as `/api/email/prefs` holds them. They live on the
/// server, not in the planner: the server sends the email, and turning one
/// off has to work even if this phone never syncs again.
struct EmailPrefs: Equatable, Sendable {
    /// Each stream's own switch. `rawValue` names match the server's keys.
    var streams: [EmailStream: Bool] = Dictionary(uniqueKeysWithValues: EmailStream.allCases.map { ($0, true) })
    /// You used an email's Unsubscribe link: no ClassPing email at all,
    /// whatever the switches say.
    var unsubscribedAll = false

    /// The settings in the server's answer, or nil when it isn't one.
    static func fromServer(_ body: JSONValue?) -> EmailPrefs? {
        guard let body, body.objectValue != nil else { return nil }
        var prefs = EmailPrefs()
        for stream in EmailStream.allCases {
            prefs.streams[stream] = body[stream.rawValue]?.boolValue ?? false
        }
        prefs.unsubscribedAll = body["unsubscribedAll"]?.boolValue == true
        return prefs
    }

    /// Whether a switch shows on: its own setting, and not unsubscribed from everything.
    func isOn(_ stream: EmailStream) -> Bool {
        (streams[stream] ?? true) && !unsubscribedAll
    }

    /// Flipping one switch: the settings to show straight away, and what to
    /// send. Turning any switch on also lifts "unsubscribed from all", or the
    /// switch would read on and still send nothing. `handleEmailPref`.
    func setting(_ stream: EmailStream, on: Bool) -> (shown: EmailPrefs, body: JSONValue) {
        let clearOptOut = on && unsubscribedAll
        var next = self
        next.streams[stream] = on
        if clearOptOut { next.unsubscribedAll = false }
        var body: [String: JSONValue] = [stream.rawValue: .bool(on)]
        if clearOptOut { body["unsubscribedAll"] = .bool(false) }
        return (next, .object(body))
    }
}

// MARK: - Deleting the account

/// What a delete-account answer means.
enum DeleteOutcome: Equatable, Sendable {
    /// Gone: the account, its server data and its photo.
    case deleted
    /// The server wants a recent sign-in first (Clerk's "reverification",
    /// within 10 minutes). Nothing was deleted.
    case needsFreshSignIn
    /// It didn't work; the words say how far it got.
    case failed(String)
}

/// Reads `/api/account`'s answer, with the web's words for each failure.
func deleteOutcome(_ reply: WebReply) -> DeleteOutcome {
    if reply.ok { return .deleted }
    // Clerk's reverification answer: 403 with `clerk_error`.
    if reply.status == 403, reply.body?["clerk_error"] != nil { return .needsFreshSignIn }
    if reply.status == 0 { return .failed(OFFLINE_MESSAGE) }
    if reply.tokenRefused { return .failed(SIGNED_OUT_MESSAGE) }
    if reply.body?["dataDeleted"]?.boolValue == true {
        return .failed("Your data was removed, but the account itself couldn't be deleted. Please try again.")
    }
    if reply.body?["partial"]?.boolValue == true {
        return .failed("Some data may have been removed, but deletion didn't finish. Please retry to complete it.")
    }
    return .failed("Couldn't delete your account. Please try again.")
}

// MARK: - Rating ClassPing

/// A word for each score, shown once a star is picked. `WORDS` in ReviewCard.tsx.
func reviewWord(_ rating: Int) -> String {
    switch rating {
    case 1: "Not for me"
    case 2: "It's rough"
    case 3: "It's alright"
    case 4: "Really like it"
    case 5: "Love it!"
    default: ""
    }
}

/// What the review card sends to `/api/feedback`: a review, its stars, the
/// comment (it may be empty) and your username, so the note is yours.
func reviewBody(rating: Int, message: String, name: String) -> JSONValue {
    .object([
        "kind": .string("review"),
        "rating": .int(rating),
        "message": .string(message),
        "name": .string(name),
    ])
}

/// What to say when a review didn't send.
func reviewProblem(_ reply: WebReply) -> String {
    if reply.status == 0 { return OFFLINE_MESSAGE }
    if reply.tokenRefused { return SIGNED_OUT_MESSAGE }
    return reply.message ?? "That didn't send. Please try again."
}
