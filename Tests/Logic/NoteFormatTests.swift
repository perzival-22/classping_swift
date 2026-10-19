// NoteFormatTests.swift: Phase 8c. The formatting bar is phone-only (the
// web's toolbar changes rich text, not markdown), so there's no web test to
// copy. These pin down what each button types, and check with the reader
// (parseBlocks, noteRuns) that what the bar writes is drawn as meant.
// Run: scripts/test-logic.sh. Kelvin does not type this file.

import Foundation
import Testing
@testable import CPLogic

/// A NoteEdit in one line: the text, and the selection from `lo` to `hi`.
private func e(_ text: String, _ lo: Int, _ hi: Int) -> NoteEdit {
    NoteEdit(text: text, selection: lo..<hi)
}

@Suite struct ToggleMarkTests {
    @Test func boldWrapsTheSelectedWordsAndASecondTapUnwrapsThem() {
        let once = toggleMark(.bold, in: e("a cell wall", 2, 6))
        #expect(once == e("a **cell** wall", 4, 8))
        #expect(toggleMark(.bold, in: once) == e("a cell wall", 2, 6))
    }

    @Test func selectingTheMarkersTooTakesThemOff() {
        #expect(toggleMark(.bold, in: e("a **cell** wall", 2, 10)) == e("a cell wall", 2, 6))
    }

    @Test func aCaretGetsAnEmptyPairAndASecondTapTakesItAway() {
        let once = toggleMark(.bold, in: e("ab", 1, 1))
        #expect(once == e("a****b", 3, 3))
        #expect(toggleMark(.bold, in: once) == e("ab", 1, 1))
    }

    @Test func eachLineIsWrappedOnItsOwn() {
        let once = toggleMark(.bold, in: e("one\ntwo", 0, 7))
        #expect(once == e("**one**\n**two**", 2, 13))
        #expect(toggleMark(.bold, in: once) == e("one\ntwo", 0, 7))
    }

    @Test func leavesOutALinesStartAndTheSpacesAtItsEnds() {
        let out = toggleMark(.bold, in: e("- milk \n## Title", 0, 16))
        #expect(out == e("- **milk** \n## **Title**", 4, 22))
        #expect(parseBlocks(out.text).map(\.kind) == [.ul, .h2])
    }

    @Test func italicAndBoldShareTheStars() {
        let both = toggleMark(.italic, in: e("**x**", 2, 3))
        #expect(both == e("***x***", 3, 4))
        let run = noteRuns(both.text)
        #expect(run.count == 1 && run[0].bold && run[0].italic)
        #expect(toggleMark(.italic, in: both) == e("**x**", 2, 3))
        #expect(toggleMark(.bold, in: both) == e("*x*", 1, 2))
    }

    @Test func aWordInTheMiddleOfBoldComesOutOfIt() {
        let out = toggleMark(.bold, in: e("**one two three**", 6, 9))
        #expect(out == e("**one **two** three**", 8, 11))
        #expect(noteRuns(out.text).map { "\($0.text)|\($0.bold)" } == ["one |true", "two|false", " three|true"])
    }

    @Test func theLastWordOfBoldComesOutOfIt() {
        let out = toggleMark(.bold, in: e("**one two**", 6, 9))
        #expect(out == e("**one **two", 8, 11))
        #expect(noteRuns(out.text).map { "\($0.text)|\($0.bold)" } == ["one |true", "two|false"])
    }

    @Test func underlineAndCodeWrapToo() {
        #expect(toggleMark(.underline, in: e("key", 0, 3)) == e("__key__", 2, 5))
        #expect(toggleMark(.code, in: e("ATP", 0, 3)) == e("`ATP`", 1, 4))
        #expect(noteRuns("__key__ `ATP`").map { "\($0.text)|\($0.underline)|\($0.code)" }
                == ["key|true|false", " |false|false", "ATP|false|true"])
    }

    @Test func onlySpacesSelectedChangesNothing() {
        #expect(toggleMark(.bold, in: e("a   b", 1, 4)) == e("a   b", 1, 4))
    }

    @Test func countsAnEmojiAsTwoUnits() {
        #expect(toggleMark(.bold, in: e("😀 hi", 3, 5)) == e("😀 **hi**", 5, 7))
    }
}

@Suite struct HighlightAndPenTests {
    @Test func highlightOnlyEverAdds() {
        let once = highlight(in: e("a key term", 2, 5))
        #expect(once == e("a ==key== term", 4, 7))
        #expect(highlight(in: once) == once)
        #expect(highlight(in: e("a ==key== term", 5, 5)) == e("a ==key== term", 5, 5))
        #expect(noteRuns(once.text).map { "\($0.text)|\($0.highlight)" } == ["a |false", "key|true", " term|false"])
    }

    @Test func clearTakesOffTheWholeHighlightACaretIsIn() {
        #expect(clearHighlight(in: e("a ==key term== b", 6, 6)) == e("a key term b", 2, 10))
    }

    @Test func clearTakesOffEveryHighlightSelected() {
        #expect(clearHighlight(in: e("==a== and ==b==", 0, 15)) == e("a and b", 0, 7))
        #expect(clearHighlight(in: e("no marks", 0, 8)) == e("no marks", 0, 8))
    }

    @Test func aPenWrapsThenRecoloursThenComesOff() {
        let red = paint("red", in: e("ink", 0, 3))
        #expect(red == e("[[red|ink]]", 6, 9))
        #expect(noteRuns(red.text).first?.pen == "red")
        let blue = paint("blue", in: e(red.text, 7, 7))
        #expect(blue == e("[[blue|ink]]", 0, 12))
        #expect(paint(nil, in: blue) == e("ink", 0, 3))
        #expect(paint(nil, in: e("ink", 0, 3)) == e("ink", 0, 3))
    }

    @Test func aPenOnTwoLinesWrapsEach() {
        #expect(paint("green", in: e("a\nb", 0, 3)) == e("[[green|a]]\n[[green|b]]", 8, 21))
    }
}

@Suite struct LineStyleTests {
    @Test func bulletStartsALineAndASecondTapEndsIt() {
        let once = setLineStyle(.bullet, in: e("milk", 4, 4))
        #expect(once == e("- milk", 6, 6))
        #expect(setLineStyle(.bullet, in: once) == e("milk", 4, 4))
    }

    @Test func theCaretKeepsItsPlaceInTheWords() {
        let once = setLineStyle(.bullet, in: e("milk", 2, 2))
        #expect(once == e("- milk", 4, 4))
        #expect(setLineStyle(.body, in: once) == e("milk", 2, 2))
    }

    @Test func numbersCountUpAndStartAgainAfterABlankLine() {
        let out = setLineStyle(.numbered, in: e("a\nb\n\nc", 0, 6))
        #expect(out == e("1. a\n2. b\n\n1. c", 3, 15))
        #expect(listNumbers(parseBlocks(out.text)) == [1, 2, 0, 1])
    }

    @Test func aHeadingSwapsAListsStart() {
        #expect(setLineStyle(.heading2, in: e("- milk", 6, 6)) == e("## milk", 7, 7))
    }

    @Test func aTickedBoxStaysTicked() {
        #expect(setLineStyle(.checkbox, in: e("- [x] done\nnew", 0, 14)) == e("- [x] done\n- [ ] new", 6, 20))
    }

    @Test func anEmptyLineStartsAList() {
        #expect(setLineStyle(.bullet, in: e("a\n", 2, 2)) == e("a\n- ", 4, 4))
    }

    @Test func aWholeLinePickedWithItsReturnLeavesTheNextLineAlone() {
        #expect(setLineStyle(.bullet, in: e("a\nb", 0, 2)) == e("- a\nb", 2, 4))
    }

    @Test func theReaderDrawsWhatTheBarWrites() {
        let titled = setLineStyle(.heading1, in: e("Cells\nnucleus\nribosome", 0, 0))
        let listed = setLineStyle(.bullet, in: NoteEdit(text: titled.text, selection: 8..<24))
        #expect(listed.text == "# Cells\n- nucleus\n- ribosome")
        #expect(parseBlocks(listed.text).map(\.kind) == [.h1, .ul, .ul])
        let quoted = setLineStyle(.quote, in: e("said", 0, 0))
        #expect(quoted.text == "> said")
        #expect(parseBlocks(quoted.text).map(\.kind) == [.quote])
    }

    @Test func readsHowALineStarts() {
        #expect(linePrefix("### Deep").style == .heading3)
        #expect(linePrefix("#nospace").style == .body)
        #expect(linePrefix("- [X] Big") == (style: .checkbox, length: 6))
        #expect(linePrefix("12. twelve") == (style: .numbered, length: 4))
        #expect(linePrefix(">quote").length == 1)
    }
}

@Suite struct CodeBlockTests {
    @Test func fencesTheLinesTheSelectionTouches() {
        #expect(insertCodeBlock(in: e("x = 1\ny = 2", 0, 3)) == e("```\nx = 1\n```\ny = 2", 4, 9))
        #expect(parseBlocks("```\nx = 1\n```\ny = 2").map(\.kind) == [.code, .p])
    }

    @Test func anEmptyLineGetsAnEmptyBlock() {
        #expect(insertCodeBlock(in: e("", 0, 0)) == e("```\n\n```", 4, 4))
    }
}
