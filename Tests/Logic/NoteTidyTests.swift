// NoteTidyTests.swift: Phase 8c. The Swift twins of lib/tidy-note.test.ts
// and lib/line-diff.test.ts, plus cases marked "web:", whose answers came
// from running lib/tidy-note.ts and lib/line-diff.ts themselves in node
// (2026-10-18).
// Run: scripts/test-logic.sh. Kelvin does not type this file.

import Foundation
import Testing
@testable import CPLogic

@Suite struct TidyNoteTests {
    @Test func promotesAnAllCapsLineToAHeadingAndGroupsLooseLines() {
        let out = tidyNote("NOTES\nfirst point\nsecond point")
        #expect(out.changed)
        #expect(out.body == "## NOTES\n- first point\n- second point")
    }

    @Test func promotesAShortTrailingColonLabelWithContentBeneathIt() {
        #expect(tidyNote("Topic:\nsome detail here").body == "## Topic\nsome detail here")
    }

    @Test func leavesAColonLabelAloneWhenNothingFollowsIt() {
        #expect(!tidyNote("Topic:").changed)
    }

    @Test func normalisesBulletGlyphsToADash() {
        #expect(tidyNote("* one\n* two").body == "- one\n- two")
        #expect(tidyNote("• alpha\n• beta").body == "- alpha\n- beta")
    }

    @Test func collapsesBlankRunsAndTrimsKeepingParagraphsApart() {
        #expect(tidyNote("a\n\n\n\nb\n").body == "a\n\nb")
    }

    @Test func doesNotBulletAWrappedSentence() {
        let prose = "This sentence wraps across a line break,\nand finishes on the next line."
        #expect(!tidyNote(prose).changed)
    }

    @Test func leavesCodeTablesAndColumnsUntouched() {
        #expect(!tidyNote("```\nSHOULD NOT BECOME A HEADING\nx = 1\n```").changed)
        #expect(!tidyNote("| a | b |\n| --- | --- |\n| 1 | 2 |").changed)
        #expect(!tidyNote(":::columns\n:::col\nLEFT\n:::col\nright\n:::").changed)
    }

    @Test func isIdempotent() {
        let once = tidyNote("NOTES\nfirst point\nsecond point").body
        let twice = tidyNote(once)
        #expect(!twice.changed)
        #expect(twice.body == once)
    }

    @Test func reportsTheOriginalUntouchedWhenAlreadyTidy() {
        let tidy = "## Heading\n\n- a\n- b"
        let out = tidyNote(tidy)
        #expect(!out.changed)
        #expect(out.body == tidy)
        #expect(out.summary == "This note already looks tidy.")
    }

    // web: a messy lecture, every rule at once.
    @Test func tidiesALectureLikeTheWeb() {
        let input = "BIOLOGY 101\nCell parts:\nnucleus\nmitochondria\nribosome\n\nThe cell membrane controls what enters and leaves the cell, and it is made of a phospholipid bilayer that lets some things through.\nKEY TERMS\nosmosis\ndiffusion   \n\n\n\n```\nCODE STAYS\n```\n| a | b |   \n| --- | --- |"
        let out = tidyNote(input)
        #expect(out.body == "## BIOLOGY 101\n\n## Cell parts\n- nucleus\n- mitochondria\n- ribosome\n\nThe cell membrane controls what enters and leaves the cell, and it is made of a phospholipid bilayer that lets some things through.\n\n## KEY TERMS\n- osmosis\n- diffusion\n\n```\nCODE STAYS\n```\n| a | b |\n| --- | --- |")
        #expect(out.summary == "Added 3 headings and grouped loose lines into lists.")
    }

    // web: each of these, input → body and summary.
    @Test func matchesTheWebOnSmallCases() {
        let cases: [(String, String, String)] = [
            ("TITLE\r\nline one\r\nline two", "## TITLE\n- line one\n- line two",
             "Added a heading and grouped loose lines into lists."),
            ("PART ONE\nx\nPART TWO\ny", "## PART ONE\nx\n\n## PART TWO\ny", "Added 2 headings."),
            ("Café notes:\n• crème\n• brûlée", "## Café notes\n- crème\n- brûlée", "Added a heading."),
            ("Week 3: what we covered\nphotosynthesis\nrespiration",
             "- Week 3: what we covered\n- photosynthesis\n- respiration", "Grouped loose lines into lists."),
            ("- already\n- a list\nloose one\nloose two",
             "- already\n- a list\n- loose one\n- loose two", "Grouped loose lines into lists."),
            ("NOTE\n## Real heading\ntext", "## NOTE\n\n## Real heading\ntext", "Added a heading."),
            ("   \n\nhello\n\n", "hello", "Tidied the spacing."),
            ("x\n:::columns\n:::col\nLEFT\n:::col\nright\n:::\nAFTER\ny",
             "x\n:::columns\n:::col\nLEFT\n:::col\nright\n:::\n\n## AFTER\ny", "Added a heading."),
            ("Ch. 3:\ncells", "- Ch. 3:\n- cells", "Grouped loose lines into lists."),
            ("DNA\n1. one\n2. two", "## DNA\n1. one\n2. two", "Added a heading."),
            ("a b c d e f g h i:\nbody", "- a b c d e f g h i:\n- body", "Grouped loose lines into lists."),
            ("a b c d e f g h:\nbody", "## a b c d e f g h\nbody", "Added a heading."),
        ]
        for (input, body, summary) in cases {
            let out = tidyNote(input)
            #expect(out.changed)
            #expect(out.body == body)
            #expect(out.summary == summary)
        }
    }

    // web: a trailing comma keeps a line out of a list, and one loose line
    // isn't a list, so nothing changes.
    @Test func leavesACommaLineAndALoneLineAlone() {
        let out = tidyNote("apples,\npears")
        #expect(!out.changed)
        #expect(out.body == "apples,\npears")
    }

    // Phone-only: a tidy that would go past the note limit is refused.
    @Test func refusesATidyPastTheNoteLimit() {
        let long = String(repeating: "ab\n", count: 6_666) + "c"   // 19,999 units
        #expect(noteLength(long) == 19_999)
        let out = tidyNote(long)   // two more characters per line would be far too many
        #expect(!out.changed)
        #expect(out.body == long)
    }
}

@Suite struct LineDiffTests {
    /// Each line as "s:text", "a:text" or "d:text", the web test's `compact`.
    private func compact(_ diff: [DiffLine]) -> [String] {
        diff.map { line in
            let tag = switch line.kind {
            case .same: "s"
            case .add: "a"
            case .del: "d"
            }
            return "\(tag):\(line.text)"
        }
    }

    @Test func marksIdenticalTextEntirelyUnchanged() {
        #expect(lineDiff("a\nb", "a\nb").allSatisfy { $0.kind == .same })
    }

    @Test func longNotesHandleUnchangedAndEntirelyReformattedLines() {
        let before = Array(repeating: "x", count: 3_500).joined(separator: "\n")
        let after = Array(repeating: "- x", count: 3_500).joined(separator: "\n")
        #expect(lineDiff(before, before).count == 3_500)
        let diff = lineDiff(before, after)
        #expect(diff.count == 7_000)
        #expect(diff.prefix(3_500).allSatisfy { $0.kind == .del && $0.text == "x" })
        #expect(diff.suffix(3_500).allSatisfy { $0.kind == .add && $0.text == "- x" })
    }

    @Test func repeatedLinesKeepTheWebsDeletionFirstTieBreak() {
        #expect(compact(lineDiff("a\nb\na", "b\na\nb"))
                == ["d:a", "s:b", "s:a", "a:b"])
    }

    @Test func keepsUntouchedBodyLinesAsContextAndFlagsAnInsertedHeading() {
        #expect(compact(lineDiff("Cells\nMitochondria", "# Cells\n\nMitochondria"))
                == ["d:Cells", "a:# Cells", "a:", "s:Mitochondria"])
    }

    @Test func surfacesADroppedLineAsADeletionWithNoMatchingAddition() {
        let diff = lineDiff("keep\ndropped\ntail", "keep\ntail")
        #expect(diff.filter { $0.kind == .del } == [DiffLine(kind: .del, text: "dropped")])
        #expect(!diff.contains { $0.kind == .add })
    }

    @Test func reconstructsEachSideFromItsOwnLineTypes() {
        let before = "one\ntwo\nthree"
        let after = "# one\ntwo\nfour"
        let diff = lineDiff(before, after)
        #expect(diff.filter { $0.kind != .add }.map(\.text).joined(separator: "\n") == before)
        #expect(diff.filter { $0.kind != .del }.map(\.text).joined(separator: "\n") == after)
    }

    // web: the same three comparisons gave exactly these.
    @Test func matchesTheWeb() {
        #expect(compact(lineDiff("a\nb\nc\nd", "x\nb\nd\ne")) == ["d:a", "a:x", "s:b", "d:c", "s:d", "a:e"])
        #expect(compact(lineDiff("", "a")) == ["d:", "a:a"])
        #expect(compact(lineDiff("NOTES\nfirst point\nsecond point", "## NOTES\n- first point\n- second point"))
                == ["d:NOTES", "d:first point", "d:second point", "a:## NOTES", "a:- first point", "a:- second point"])
    }
}
