// WebCallsTests.swift: what the phone sends to classping.space's API and how
// it reads the answers (Logic/WebCalls.swift). The feed case reads the JSON
// the web's own parseIcs produced in node (WebValues14e.swift) and checks it
// against the phone's own reader of the same calendar, so a feed read by the
// server and a file read on the phone come out the same.
// Run: tools/logic-test.sh (CI: scripts/test-logic.sh). Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

/// Parses JSON text the way an answer arrives.
private func json(_ text: String) -> JSONValue? {
    try? JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
}

@Suite struct ServerFeedTests {
    @Test func readsTheServersAnswerForAFeed() {
        let result = importResult(fromServer: json(WEB_FEED_SERVER_JSON))
        #expect(result?.classes.map(\.name) == ["Biology 110", "World History"])
        #expect(result?.classes.first?.days == [1, 3])
        #expect(result?.classes.first?.start == 555)
        #expect(result?.classes.first?.room == "Science Hall 204")
        #expect(result?.classes.first?.sourceUID == "cls-bio@school")
        #expect(result?.classes.last?.room == nil)
        #expect(result?.classes.last?.color == "coral")
        #expect(result?.tasks.map(\.title) == ["Essay 2 , final draft", "Midterm exam"])
        #expect(result?.tasks.first?.dueTime == "23:59")
        #expect(result?.tasks.last?.dueTime == nil)
        #expect(result?.tasks.last?.kind == "exam")
        #expect(result?.skipped == 2)
        #expect(result?.cancelled == ["task-off@school"])
        #expect(result?.term == TermDateSuggestion(start: "2026-09-01", end: "2026-12-11"))
    }

    @Test func theServersAnswerMatchesThePhonesOwnReading() {
        var parts = DateComponents()
        parts.year = WEB_FEED_NOW_PARTS.year
        parts.month = WEB_FEED_NOW_PARTS.month
        parts.day = WEB_FEED_NOW_PARTS.day
        parts.hour = WEB_FEED_NOW_PARTS.hour
        parts.minute = WEB_FEED_NOW_PARTS.minute
        let now = Calendar.current.date(from: parts) ?? Date(timeIntervalSince1970: 0)
        #expect(importResult(fromServer: json(WEB_FEED_SERVER_JSON)) == parseICS(WEB_FEED_ICS, now: now))
    }

    @Test func refusesAnAnswerThatIsntAnImport() {
        #expect(importResult(fromServer: nil) == nil)
        #expect(importResult(fromServer: json(#"{"error":"not_a_calendar"}"#)) == nil)
        #expect(importResult(fromServer: json("[1,2]")) == nil)
    }

    @Test func skipsAMalformedPieceButKeepsTheRest() {
        let body = json(#"{"classes":[{"name":"Ok","days":[0,9],"start":540,"end":600},{"name":"No times"}],"tasks":[{"title":""},{"title":"Quiz 1","due":null,"dueTime":null,"kind":"quiz"}],"skipped":0,"cancelled":[]}"#)
        let result = importResult(fromServer: body)
        #expect(result?.classes.map(\.name) == ["Ok"])
        #expect(result?.classes.first?.days == [0])
        #expect(result?.classes.first?.short == "Ok")
        #expect(result?.tasks.map(\.title) == ["Quiz 1"])
        #expect(result?.tasks.first?.kind == "assignment")
    }

    @Test func saysWhyAFeedFailed() {
        #expect(feedProblem(WebReply(status: 400, body: json(#"{"error":"not_a_calendar","message":"That link didn't return a calendar feed."}"#)))
                == "That link didn't return a calendar feed.")
        #expect(feedProblem(WebReply(status: 502)) == "Couldn't import that calendar.")
        #expect(feedProblem(WebReply(status: 0)) == "Something went wrong. Check the link and try again.")
        #expect(feedProblem(WebReply(status: 307)) == SIGNED_OUT_MESSAGE)
    }
}

@Suite struct WebReplyTests {
    @Test func knowsWhichAnswersMeanTheTokenWasRefused() {
        #expect(WebReply(status: 401).tokenRefused)
        #expect(WebReply(status: 404).tokenRefused)
        #expect(WebReply(status: 307).tokenRefused)
        #expect(!WebReply(status: 200).tokenRefused)
        #expect(!WebReply(status: 403).tokenRefused)
        #expect(!WebReply(status: 0).tokenRefused)
    }

    @Test func readsTheServersSentence() {
        #expect(WebReply(status: 429, body: json(#"{"message":"  Too many imports. Try again shortly. "}"#)).message
                == "Too many imports. Try again shortly.")
        #expect(WebReply(status: 429, body: json(#"{"error":"rate_limited"}"#)).message == nil)
    }
}

@Suite struct AvatarUploadTests {
    @Test func takesOnlyAnHttpsAddress() {
        #expect(uploadedAvatarURL(WebReply(status: 200, body: json(#"{"url":"https://blob.example/avatars/u.webp"}"#)))
                == "https://blob.example/avatars/u.webp")
        #expect(uploadedAvatarURL(WebReply(status: 501, body: json(#"{"error":"blob_not_configured"}"#))) == nil)
        #expect(uploadedAvatarURL(WebReply(status: 200, body: json(#"{"url":"http://insecure"}"#))) == nil)
    }

    @Test func versionsTheAddressSoANewPhotoIsAChange() {
        let at = Date(timeIntervalSince1970: 1_761_134_400)
        #expect(versionedAvatarURL("https://b/a.webp", at: at) == "https://b/a.webp?v=1761134400000")
        #expect(versionedAvatarURL("https://b/a.webp?x=1", at: at) == "https://b/a.webp?x=1&v=1761134400000")
    }
}

@Suite struct EmailPrefsTests {
    @Test func readsTheServersSettings() {
        let prefs = EmailPrefs.fromServer(json(#"{"preClass":true,"postClass":false,"dailyDigest":true,"weekly":true,"assignmentDue":false,"unsubscribedAll":false}"#))
        #expect(prefs?.isOn(.preClass) == true)
        #expect(prefs?.isOn(.postClass) == false)
        #expect(prefs?.isOn(.assignmentDue) == false)
        #expect(EmailPrefs.fromServer(nil) == nil)
    }

    @Test func unsubscribedFromAllShowsEverySwitchOff() {
        var prefs = EmailPrefs()
        prefs.unsubscribedAll = true
        #expect(EmailStream.allCases.allSatisfy { !prefs.isOn($0) })
    }

    @Test func turningASwitchOnLiftsTheUnsubscribe() {
        var prefs = EmailPrefs()
        prefs.unsubscribedAll = true
        let change = prefs.setting(.weekly, on: true)
        #expect(!change.shown.unsubscribedAll)
        #expect(change.shown.isOn(.weekly))
        #expect(change.body == .object(["weekly": .bool(true), "unsubscribedAll": .bool(false)]))
    }

    @Test func turningASwitchOffSendsOnlyThatSwitch() {
        let change = EmailPrefs().setting(.preClass, on: false)
        #expect(change.body == .object(["preClass": .bool(false)]))
        #expect(!change.shown.isOn(.preClass))
        #expect(change.shown.isOn(.postClass))
    }

    @Test func switchesKeepTheWebsWordsAndOrder() {
        #expect(EmailStream.allCases.map(\.label)
                == ["Before class", "After class", "Assignment due soon", "End-of-day digest", "Week ahead"])
    }
}

@Suite struct DeleteAccountTests {
    @Test func readsEachAnswer() {
        #expect(deleteOutcome(WebReply(status: 200, body: json(#"{"ok":true}"#))) == .deleted)
        #expect(deleteOutcome(WebReply(status: 403, body: json(#"{"clerk_error":{"type":"forbidden","reason":"reverification-error"}}"#)))
                == .needsFreshSignIn)
        #expect(deleteOutcome(WebReply(status: 502, body: json(#"{"error":"account_delete_failed","dataDeleted":true,"partial":true}"#)))
                == .failed("Your data was removed, but the account itself couldn't be deleted. Please try again."))
        #expect(deleteOutcome(WebReply(status: 502, body: json(#"{"error":"account_delete_failed","dataDeleted":false,"partial":true}"#)))
                == .failed("Some data may have been removed, but deletion didn't finish. Please retry to complete it."))
        #expect(deleteOutcome(WebReply(status: 503, body: json(#"{"error":"delete_unavailable","dataDeleted":false}"#)))
                == .failed("Couldn't delete your account. Please try again."))
        #expect(deleteOutcome(WebReply(status: 0)) == .failed(OFFLINE_MESSAGE))
    }
}

@Suite struct ReviewTests {
    @Test func sendsAReviewWithItsStarsAndName() {
        #expect(reviewBody(rating: 4, message: "", name: "kelvin")
                == .object(["kind": .string("review"), "rating": .number(4),
                            "message": .string(""), "name": .string("kelvin")]))
    }

    @Test func hasAWordForEachScore() {
        #expect((1...5).map(reviewWord) == ["Not for me", "It's rough", "It's alright", "Really like it", "Love it!"])
        #expect(reviewWord(0) == "")
    }

    @Test func saysWhyItDidntSend() {
        #expect(reviewProblem(WebReply(status: 503, body: json(#"{"error":"unavailable","message":"Feedback isn't configured yet. Email me directly instead."}"#)))
                == "Feedback isn't configured yet. Email me directly instead.")
        #expect(reviewProblem(WebReply(status: 0)) == OFFLINE_MESSAGE)
        #expect(reviewProblem(WebReply(status: 500)) == "That didn't send. Please try again.")
    }
}
