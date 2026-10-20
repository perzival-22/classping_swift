// ScaleDraftTests.swift: Phase 9b. The editor's text-to-number rules, the
// Swift twin of GradeScaleEditor.tsx's toDraft/fromDraft and of JavaScript's
// Number() for these fields ("web:" values from node 22, 2026-10-20).
import Foundation
import Testing
@testable import CPLogic

@Suite struct ScaleDraftTests {
    private let point = Locale(identifier: "en_US_POSIX")
    private let comma = Locale(identifier: "de_DE")

    @Test func blankIsZeroAndUnreadableIsNaN() {
        // web: Number("") is 0, Number(" 5 ") is 5, Number("1,5") is NaN.
        #expect(scaleNumber("", locale: point) == 0)
        #expect(scaleNumber("   ", locale: point) == 0)
        #expect(scaleNumber(" 5 ", locale: point) == 5)
        #expect(scaleNumber("1,5", locale: point).isNaN)
        #expect(scaleNumber("abc", locale: point).isNaN)
    }

    @Test func numberShapesJavaScriptAccepts() {
        // web: Number("5.") 5, Number(".5") 0.5, Number("1e2") 100, Number("+5") 5.
        #expect(scaleNumber("5.", locale: point) == 5)
        #expect(scaleNumber(".5", locale: point) == 0.5)
        #expect(scaleNumber("1e2", locale: point) == 100)
        #expect(scaleNumber("+5", locale: point) == 5)
    }

    @Test func theDecimalCommaIsAccepted() {
        #expect(scaleNumber("3,7", locale: comma) == 3.7)
        #expect(scaleNumber("3.7", locale: comma) == 3.7)
    }

    @Test func savedBandsRoundTripThroughTheRows() {
        for locale in [point, comma] {
            let rows = scaleDraftRows(from: DEFAULT_SCALE, locale: locale)
            #expect(rows.count == DEFAULT_SCALE.count)
            #expect(Set(rows.map(\.id)).count == rows.count)
            #expect(scaleBands(from: rows, locale: locale) == DEFAULT_SCALE)
        }
        #expect(scaleDraftRows(from: [DEFAULT_SCALE[1]], locale: point).first?.points == "3.7")
        #expect(scaleDraftRows(from: [DEFAULT_SCALE[1]], locale: comma).first?.points == "3,7")
        #expect(scaleDraftRows(from: [DEFAULT_SCALE[0]], locale: point).first?.min == "93")
    }

    @Test func aBlankRowIsDroppedAndAHalfTypedOneIsKept() {
        // web: normalizeScale(fromDraft([{ letter: "B", min: "", points: "" }]))
        //      is [{ letter: "B", min: 0, points: 0 }].
        let rows = [ScaleDraftRow(), ScaleDraftRow(letter: "B")]
        #expect(normalizeScale(scaleBands(from: rows, locale: point))
                == [ScaleBand(min: 0, letter: "B", points: 0)])
        // web: both rows start at 0 (blank reads as 0), so the web warns about that too.
        #expect(scaleIssues(scaleBands(from: rows, locale: point)) == [
            "Row 1 has no letter.",
            "Two bands both start at 0%, only the first will ever match.",
        ])
    }
}
