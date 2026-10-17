// Phase 6a: quote normalization and epoch-aligned two-hour rotation.
import Foundation
import Testing
@testable import CPLogic

@Suite struct QuotesTests {
    @Test func trimsWhitespaceAndDropsBlankLines() {
        #expect(normalizeQuotes(["  Keep going. \n", "", " \t\n", "\tStart small."])
                == ["Keep going.", "Start small."])
    }

    @Test func capsEachQuoteAtTwoHundredCharacters() {
        #expect(maxQuoteChars == 200)
        #expect(normalizeQuotes(["  " + String(repeating: "a", count: 201) + "  "])
                == [String(repeating: "a", count: 200)])
    }

    @Test func capsAtThirtyNonemptyQuotes() {
        #expect(maxQuotes == 30)
        let quotes = (0..<35).map { "Quote \($0)" }
        #expect(normalizeQuotes(["", " "] + quotes) == Array(quotes.prefix(30)))
    }

    @Test func keepsOrderDuplicatesAndUnicodeText() {
        #expect(normalizeQuotes(["Go", "Go", " 前へ 🌿 "]) == ["Go", "Go", "前へ 🌿"])
    }

    @Test func emptyPersonalListUsesBuiltInRotation() {
        #expect(defaultQuotes.count == 10)
        #expect(quoteFor([], Date(timeIntervalSince1970: 0))
                == "Small steps every day add up to big results.")
        #expect(quoteFor([], Date(timeIntervalSince1970: 9 * 7200))
                == "Show up, even when it's just for ten minutes.")
        #expect(quoteFor([], Date(timeIntervalSince1970: 10 * 7200)) == defaultQuotes[0])
    }

    @Test func personalQuotesReplaceBuiltInList() {
        #expect(quoteFor(["Mine", "Also mine"], Date(timeIntervalSince1970: 0)) == "Mine")
        #expect(quoteFor(["Mine", "Also mine"], Date(timeIntervalSince1970: 7200)) == "Also mine")
    }

    @Test func rotatesAtExactTwoHourBoundaries() {
        let quotes = ["First", "Second", "Third"]
        #expect(quoteFor(quotes, Date(timeIntervalSince1970: 7199.999)) == "First")
        #expect(quoteFor(quotes, Date(timeIntervalSince1970: 7200)) == "Second")
        #expect(quoteFor(quotes, Date(timeIntervalSince1970: 14400)) == "Third")
        #expect(quoteFor(quotes, Date(timeIntervalSince1970: 21600)) == "First")
    }

    @Test func aSingleQuoteAlwaysShows() {
        for seconds: Double in [-7200, 0, 7200, 1_800_000_000] {
            #expect(quoteFor(["Keep going"], Date(timeIntervalSince1970: seconds)) == "Keep going")
        }
    }

    @Test func negativeEpochSlotsUsePositiveModuloAndFloor() {
        let quotes = ["First", "Second", "Third"]
        #expect(quoteFor(quotes, Date(timeIntervalSince1970: -1)) == "Third")
        #expect(quoteFor(quotes, Date(timeIntervalSince1970: -7200)) == "Third")
        #expect(quoteFor(quotes, Date(timeIntervalSince1970: -7201)) == "Second")
    }
}
