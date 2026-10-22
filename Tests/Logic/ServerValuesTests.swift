// ServerValuesTests.swift: the moments, days and feed names of Phase 14b
// (Logic/ServerValues.swift) against what the web's own Date.parse,
// toISOString and feedLabelFromUrl answered (WebValues14b.swift, "web:").
// Run: tools/logic-test.sh, in every zone. Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

@Suite struct ServerValuesTests {
    // MARK: moments from the server (web: Date.parse, to the whole second)

    @Test(arguments: WEB_INSTANTS.map(\.text))
    func readsAMomentAsTheWebDoes(_ text: String) {
        let expected = WEB_INSTANTS.first { $0.text == text }?.seconds
        // A time with no zone is read on your own clock, so the web's answer
        // (worked out in New York) only applies there.
        let local = text.count == 19 && !text.hasSuffix("Z")
        if local && TimeZone.current.identifier != "America/New_York" { return }
        #expect(instantFromServer(text)?.timeIntervalSince1970 == expected, "web: \(text)")
    }

    @Test func noTextIsNoMoment() {
        #expect(instantFromServer(nil) == nil)
    }

    @Test func aTimeWithNoZoneIsYourOwnClock() {
        let parts = DateComponents(year: 2026, month: 9, day: 21, hour: 14, minute: 13, second: 20)
        #expect(instantFromServer("2026-09-21T14:13:20") == Calendar.autoupdatingCurrent.date(from: parts))
    }

    @Test func refusesAMonthOrClockThatCantBe() {
        #expect(instantFromServer("2026-13-01T00:00:00Z") == nil)
        #expect(instantFromServer("2026-09-21T14:61:00Z") == nil)
        #expect(instantFromServer("2026-9-21") == nil)
    }

    // MARK: moments to the server (web: toISOString)

    @Test func writesAMomentAsTheWebDoes() {
        for (seconds, iso) in WEB_ISO {
            #expect(serverInstant(Date(timeIntervalSince1970: seconds)) == iso, "web: \(iso)")
        }
    }

    @Test func dropsTheFractionTowardThePast() {
        // D-73: the phone keeps whole seconds, so .999 is still :20.
        #expect(serverInstant(Date(timeIntervalSince1970: 1_790_000_000.999)) == "2026-09-21T14:13:20.000Z")
        #expect(serverInstant(Date(timeIntervalSince1970: -1)) == "1969-12-31T23:59:59.000Z")
    }

    @Test func aMomentGoesAndComesBackTheSame() {
        let moment = Date(timeIntervalSince1970: 1_790_000_000)
        #expect(instantFromServer(serverInstant(moment)) == moment)
    }

    // MARK: days (web: toDate)

    @Test func cutsATimestampToItsDay() {
        #expect(serverDay("2026-09-01T12:00:00.000Z") == "2026-09-01")
        #expect(serverDay("2026-09-01") == "2026-09-01")
        #expect(serverDay("") == nil)
        #expect(serverDay(nil) == nil)
    }

    // MARK: feeds (web: feedLabelFromUrl and the link check)

    @Test func namesAFeedByItsHost() {
        for (url, label) in WEB_FEED_LABELS {
            #expect(feedLabelFromURL(url) == label, "web: \(url)")
        }
    }

    @Test func keepsOnlyWebLinks() {
        #expect(isFeedURL("https://canvas.example.edu/x.ics"))
        #expect(isFeedURL("HTTP://canvas.example.edu/x.ics"))
        #expect(!isFeedURL("ftp://files.example.edu/x.ics"))
        #expect(!isFeedURL("webcal://canvas.example.edu/x.ics"))
        #expect(!isFeedURL("https:/x"))
    }
}
