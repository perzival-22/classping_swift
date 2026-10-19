// NotesTests.swift: Phase 8a. The Swift twins of lib/notes.test.ts's
// "titles and previews", "day keys", "budget" and the plain-text cases from
// "text colour", "column blocks" and "tables". The stripMarkers and dayLabel
// expectations marked "web:" were produced by running lib/notes.ts itself
// (node, 2026-10-18), so they pin the web's exact output, quirks included.
// Run: scripts/test-logic.sh. Kelvin does not type this file.

import Foundation
import Testing
@testable import CPLogic

private func at(_ y: Int, _ mo: Int, _ d: Int, _ h: Int = 12, _ mi: Int = 0) -> Date {
    Calendar.current.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
}

/// A stand-in class: just a timetable.
private struct Subject: Schedulable {
    var id = UUID()
    var days: [Int]
    var startMin: Int
    var endMin: Int
    var room: String? = nil
    var additionalMeetings: [ClassMeeting] = []
}

@Suite struct NoteTitleTests {
    // From lib/notes.test.ts, "titles and previews".
    @Test func prefersTheTypedTitle() {
        #expect(noteTitle(title: "Week 3", body: "# Something else") == "Week 3")
    }

    @Test func fallsBackToTheFirstLineWithItsMarkersStripped() {
        #expect(noteTitle(title: "", body: "# Photosynthesis\nmore") == "Photosynthesis")
        // web: a blank title and blank lines are skipped.
        #expect(noteTitle(title: "  ", body: "\n\n  **Week 2**  \nmore") == "Week 2")
        // web: cut to 80 characters.
        #expect(noteTitle(title: "", body: String(repeating: "y", count: 100)).count == 80)
    }

    @Test func namesAnEmptyNoteRatherThanShowingABlankRow() {
        #expect(noteTitle(title: "", body: "") == "Untitled note")
    }

    @Test func previewsTheBodyAfterTheLineTheTitleTook() {
        #expect(notePreview("# Title\nfirst body line\nsecond") == "first body line second")
        // web: nothing after the first line, or nothing at all, is no preview.
        #expect(notePreview("only one line") == "")
        #expect(notePreview("\n\n") == "")
        // web: 119 characters and an ellipsis, 120 in all.
        let long = notePreview("Title\n" + String(repeating: "x", count: 130))
        #expect(long.count == 120)
        #expect(long.hasSuffix("…"))
    }

    // From "text colour": "reads the words, not the pen, in previews and exports".
    @Test func readsTheWordsNotThePen() {
        #expect(noteText("[[red|late]] again") == "late again")
        #expect(noteTitle(title: "", body: "[[blue|Lecture 4]]") == "Lecture 4")
    }

    // From "column blocks" and "tables": scaffolding never reaches plain text.
    @Test func keepsColumnFencesAndTablePipesOutOfPlainText() {
        let columns = [":::columns", ":::col", "left", ":::col", "- right", ":::"].joined(separator: "\n")
        #expect(!noteText(columns).contains(":::"))
        #expect(!notePreview(columns).contains(":::"))
        let table = ["| Week | Topic |", "| --- | --- |", "| 1 | Intro |"].joined(separator: "\n")
        #expect(!noteText(table).contains("|"))
        #expect(!noteText(table).contains("---"))
        #expect(noteText(table).contains("Week Topic"))
    }
}

@Suite struct StripMarkersTests {
    // web: every line here went through lib/notes.ts's stripMarkers.
    @Test func dropsBlockMarkers() {
        #expect(stripMarkers("# Photosynthesis") == "Photosynthesis")
        #expect(stripMarkers("### Deep") == "Deep")
        #expect(stripMarkers("- [x] Done item") == "Done item")
        #expect(stripMarkers("- [ ] Todo") == "Todo")
        #expect(stripMarkers("* bullet") == "bullet")
        #expect(stripMarkers("12. Twelfth") == "Twelfth")
        #expect(stripMarkers("> quoted") == "quoted")
        #expect(stripMarkers("   ## three spaces") == "three spaces")
        // Four spaces in is no longer a heading.
        #expect(stripMarkers("    # four spaces") == "    # four spaces")
    }

    @Test func fencesCarryNoWords() {
        #expect(stripMarkers("```swift") == "")
        #expect(stripMarkers(":::columns") == "")
        #expect(stripMarkers(":::col") == "")
        #expect(stripMarkers(":::") == "")
    }

    @Test func dropsInlineMarkersAndKeepsTheWords() {
        #expect(stripMarkers("**bold** and *it* and __under__ and ==hi== and `code`")
                == "bold and it and under and hi and code")
        #expect(stripMarkers("[[red|late]] and [[blue|early]]") == "late and early")
        #expect(stripMarkers("see [the site](https://x.y) now") == "see the site now")
        // Only the five pens are pens.
        #expect(stripMarkers("[[pink|not a pen]]") == "[[pink|not a pen]]")
        // The web's quirk, kept: the star goes, its backslash stays.
        #expect(stripMarkers("\\*literal\\* stars") == "\\literal\\ stars")
    }

    @Test func readsATableRowAsItsCells() {
        #expect(stripMarkers("| a | b \\| c |") == "a b | c")
        #expect(stripMarkers("| --- | :-: |") == "")
        #expect(tableCells("a | b") == ["a", "b"])
        #expect(isTableRuler("|---|:--:|"))
        #expect(!isTableRuler("| a | --- |"))
    }

    @Test func noteTextKeepsTheLines() {
        #expect(noteText("# Head\n- [ ] [[green|go]] **now**\n| a | b |\n| - | - |") == "Head\ngo now\na b\n")
    }
}

@Suite struct NoteDayTests {
    // From "day keys". The web's dayKey is Deadline.swift's dayOf.
    @Test func formatsALocalDateWithoutDriftingADay() {
        #expect(dayOf(at(2026, 9, 8, 0, 0)) == "2026-09-08")
    }

    @Test func namesTodayAndYesterday() {
        let today = at(2026, 9, 8)
        #expect(dayLabel("2026-09-08", today: today) == "Today")
        #expect(dayLabel("2026-09-07", today: today) == "Yesterday")
        #expect(dayLabel("2026-09-01", today: today) == "Tue, Sep 1")
        // web: other years read the same way.
        #expect(dayLabel("2026-12-25", today: today) == "Fri, Dec 25")
        #expect(dayLabel("2027-01-03", today: today) == "Sun, Jan 3")
    }

    @Test func handsBackAnythingItCantRead() {
        #expect(dayLabel("") == "")
        #expect(dayLabel("nonsense") == "nonsense")
        #expect(dayLabel("2026-9-1") == "2026-9-1")
    }
}

@Suite struct NoteBudgetTests {
    // From "budget": "refuses a single note past the per-note cap".
    @Test func refusesASingleNotePastTheCap() {
        #expect(!fitsBudget(maxNoteChars + 1))
        #expect(fitsBudget(maxNoteChars))
    }

    // Phone-only: lengths are counted as JavaScript counts them.
    @Test func countsLikeTheWeb() {
        #expect(noteLength("abc") == 3)
        #expect(noteLength("é") == 1)
        #expect(noteLength("😀") == 2)
    }
}

@Suite struct NoteSearchTests {
    @Test func searchesTitleWordsAndClassIgnoringCase() {
        #expect(noteMatches("week", title: "Week 3", body: "", subject: "Bio"))
        #expect(noteMatches("osmosis", title: "", body: "# **Osmosis** today", subject: "Bio"))
        #expect(noteMatches("BIO", title: "", body: "", subject: "Biology"))
        #expect(noteMatches("quick", title: "", body: "", subject: "Quick note"))
        #expect(!noteMatches("chem", title: "Week 3", body: "cells", subject: "Bio"))
    }

    @Test func anEmptySearchFindsNothing() {
        #expect(!noteMatches("", title: "Week 3", body: "", subject: "Bio"))
        #expect(!noteMatches("   ", title: "Week 3", body: "", subject: "Bio"))
    }

    // Markers aren't words: searching for "**" finds nothing.
    @Test func searchesTheWordsNotTheMarkers() {
        #expect(!noteMatches("**", title: "", body: "**bold**", subject: "Bio"))
    }
}

@Suite struct LiveCourseTests {
    // 2026-09-14 is a Monday. Calc meets Mon/Wed 9:00 to 10:00.
    private let calc = Subject(days: [0, 2], startMin: 540, endMin: 600)

    @Test func countsFromTheStartToTheEndInclusive() {
        #expect(liveCourseID([calc], now: at(2026, 9, 14, 8, 59)) == nil)
        #expect(liveCourseID([calc], now: at(2026, 9, 14, 9, 0)) == calc.id)
        #expect(liveCourseID([calc], now: at(2026, 9, 14, 10, 0)) == calc.id)
        #expect(liveCourseID([calc], now: at(2026, 9, 14, 10, 1)) == nil)
    }

    @Test func onlyOnItsDays() {
        #expect(liveCourseID([calc], now: at(2026, 9, 15, 9, 30)) == nil)
    }

    @Test func anAdditionalMeetingCanBeTheLiveClass() {
        let lab = ClassMeeting(days: [1], start: 840, end: 900, label: "Lab")
        let chemistry = Subject(days: [0], startMin: 540, endMin: 600,
                                additionalMeetings: [lab])
        #expect(liveCourseID([chemistry], now: at(2026, 9, 15, 14, 0)) == chemistry.id)
        #expect(liveCourseID([chemistry], now: at(2026, 9, 15, 15, 0)) == chemistry.id)
        #expect(liveCourseID([chemistry], now: at(2026, 9, 15, 15, 1)) == nil)
    }
}
