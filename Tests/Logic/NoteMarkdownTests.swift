// NoteMarkdownTests.swift: Phase 8b. The Swift twins of lib/notes.test.ts's
// "parseBlocks", "inlineToHtml", "text colour" (the rendering half), the
// parsing halves of "column blocks" and "tables", and what "mdToHtml" says
// about lists and padding. Cases marked "web:" were produced by running
// lib/notes.ts itself in node (2026-10-18), before D-39's link fix (no
// case here has an & in a link). inlineRuns is phone-only.
// Run: tools/logic-test.sh. Kelvin does not type this file.

import Foundation
import Testing
@testable import CPLogic

@Suite struct ParseBlocksTests {
    @Test func readsEveryBlockMarker() {
        let blocks = parseBlocks(["# Title", "## Sub", "### Deep", "plain", "- bullet", "1. first",
                                  "- [ ] todo", "- [x] done", "> quoted"].joined(separator: "\n"))
        #expect(blocks.map(\.kind) == [.h1, .h2, .h3, .p, .ul, .ol, .check, .check, .quote])
        #expect(blocks[7].checked)
        #expect(!blocks[6].checked)
    }

    @Test func keepsFencedCodeLiteral() {
        let blocks = parseBlocks("```\n# not a heading\n- not a bullet\n```")
        #expect(blocks.count == 1)
        #expect(blocks[0].kind == .code)
        #expect(blocks[0].text == "# not a heading\n- not a bullet")
    }

    @Test func treatsAnUnterminatedFenceAsACodeBlock() {
        let blocks = parseBlocks("```\nstill code\nmore code")
        #expect(blocks.count == 1)
        #expect(blocks[0].kind == .code)
        #expect(blocks[0].text == "still code\nmore code")
    }

    // web: the same input gave exactly these kinds and texts.
    @Test func readsAMixedNoteLikeTheWeb() {
        let blocks = parseBlocks("- a\n- b\n\n1. x\n3. y\n| a | b |\n| --- | --- |\n| x |\n> q\n   # not\n#nospace\n- [X] Big")
        #expect(blocks.map(\.kind) == [.ul, .ul, .p, .ol, .ol, .table, .quote, .p, .p, .check])
        #expect(blocks.map(\.text) == ["a", "b", "", "x", "y", "", "q", "   # not", "#nospace", "Big"])
        #expect(blocks[5].rows == [["a", "b"], ["x"]])
        #expect(blocks[9].checked)
    }

    // From "column blocks".
    @Test func parsesATwoColumnBlockEachColumnItsOwnDialect() {
        let blocks = parseBlocks([":::columns", ":::col", "left", ":::col", "- right", ":::"].joined(separator: "\n"))
        #expect(blocks.count == 1)
        #expect(blocks[0].kind == .cols)
        let cols = blocks[0].columns
        #expect(cols.count == 2)
        #expect(cols[0].map(\.kind) == [.p])
        #expect(cols[0][0].text == "left")
        #expect(cols[1].map(\.kind) == [.ul])
        #expect(cols[1][0].text == "right")
    }

    @Test func aStrayColumnsWithNoCloseStillRendersWhatItHas() {
        let blocks = parseBlocks(":::columns\n:::col\nkept")
        #expect(blocks.count == 1)
        #expect(blocks[0].kind == .cols)
        #expect(blocks[0].columns[0][0].text == "kept")
    }

    @Test func aFenceInsideAColumnKeepsItsColons() {
        let blocks = parseBlocks(":::columns\n```\n:::\n```\n:::")
        #expect(blocks.count == 1)
        #expect(blocks[0].columns[0].map(\.kind) == [.code])
        #expect(blocks[0].columns[0][0].text == ":::")
    }

    // From "tables".
    @Test func parsesAPipeTableIntoRowsHeaderFirst() {
        let blocks = parseBlocks(["| Week | Topic |", "| --- | --- |", "| 1 | Intro |"].joined(separator: "\n"))
        #expect(blocks.count == 1)
        #expect(blocks[0].kind == .table)
        #expect(blocks[0].rows == [["Week", "Topic"], ["1", "Intro"]])
    }

    @Test func onlyTreatsItAsATableWhenTheRulerRowIsPresent() {
        #expect(parseBlocks("| a | b |\n| c | d |").map(\.kind) == [.p, .p])
    }

    // From "mdToHtml": "pads a short body row to the header width".
    @Test func padsAShortBodyRowToTheHeaderWidth() {
        let rows = parseBlocks("| a | b |\n| --- | --- |\n| x |")[0].rows
        #expect(tableGrid(rows) == [["a", "b"], ["x", ""]])
    }

    // From "mdToHtml": "groups consecutive list items into one list" and
    // "starts a new list when the kind changes". The web's <ol> counts itself.
    @Test func numbersEachRunOfNumberedItemsFromOne() {
        #expect(listNumbers(parseBlocks("1. a\n2. b")) == [1, 2])
        #expect(listNumbers(parseBlocks("- a\n1. b")) == [0, 1])
        #expect(listNumbers(parseBlocks("3. a\n7. b")) == [1, 2])
        #expect(listNumbers(parseBlocks("1. a\n- b\n1. c")) == [1, 0, 1])
    }
}

@Suite struct InlineToHtmlTests {
    // From "inlineToHtml".
    @Test func mapsTheInlineDialect() {
        #expect(inlineToHtml("**b**") == "<b>b</b>")
        #expect(inlineToHtml("*i*") == "<i>i</i>")
        #expect(inlineToHtml("__u__") == "<u>u</u>")
        #expect(inlineToHtml("==h==") == "<mark>h</mark>")
        #expect(inlineToHtml("`c`") == "<code>c</code>")
    }

    @Test func readsBoldBeforeItalic() {
        #expect(inlineToHtml("**both**") == "<b>both</b>")
    }

    @Test func leavesCodeSpansLiteral() {
        #expect(inlineToHtml("`**x**`") == "<code>**x**</code>")
    }

    @Test func honoursBackslashEscapes() {
        #expect(inlineToHtml("\\*not italic\\*") == "*not italic*")
    }

    @Test func linksOnlyToSchemesThatCantRunCode() {
        #expect(inlineToHtml("[a](https://x.test)").contains("href=\"https://x.test\""))
        #expect(inlineToHtml("[a](mailto:x@y.test)").contains("mailto:x@y.test"))
        let js = inlineToHtml("[a](javascript:alert(1))")
        #expect(!js.contains("<a"))
        #expect(!js.contains("href"))
        #expect(js == "[a](javascript:alert(1))")
    }

    // From "text colour".
    @Test func rendersAPenAsANamedSpan() {
        #expect(inlineToHtml("[[red|late]]") == "<span data-note-color=\"red\">late</span>")
    }

    @Test func onlyKnowsThePensItShipsWith() {
        #expect(inlineToHtml("[[chartreuse|x]]") == "[[chartreuse|x]]")
    }

    @Test func parsesTheMarkersInsideAColouredRun() {
        #expect(inlineToHtml("[[blue|**due** friday]]")
                == "<span data-note-color=\"blue\"><b>due</b> friday</span>")
    }

    @Test func endsARunAtItsOwnMarkerSoALineCanHoldTwo() {
        #expect(inlineToHtml("[[red|a]] and [[green|b]]")
                == "<span data-note-color=\"red\">a</span> and <span data-note-color=\"green\">b</span>")
    }

    // From "mdToHtml": "escapes markup in the note body".
    @Test func escapesMarkupInTheNoteBody() {
        let html = inlineToHtml(escapeHtml("<img src=x onerror=alert(1)>"))
        #expect(!html.contains("<img"))
        #expect(html.contains("&lt;img"))
    }

    // web: each of these is lib/notes.ts's output for the same escaped line.
    @Test func matchesTheWebLineForLine() {
        let cases: [(String, String)] = [
            ("**a __b** c__", "<b>a <u>b</b> c</u>"),
            ("[](https://x.y)", "<a href=\"https://x.y\" target=\"_blank\" rel=\"noreferrer noopener\">https://x.y</a>"),
            ("[[red|==hi==]]", "<span data-note-color=\"red\"><mark>hi</mark></span>"),
            ("a < b & \"c\"", "a &lt; b &amp; &quot;c&quot;"),
            ("*a* and **b** and *c*", "<i>a</i> and <b>b</b> and <i>c</i>"),
            ("2*3*4", "2<i>3</i>4"),
            ("==a **b** c==", "<mark>a <b>b</b> c</mark>"),
            ("`<b>`", "<code>&lt;b&gt;</code>"),
            ("mixed `code` and **[x](mailto:a@b.c)**",
             "mixed <code>code</code> and <b><a href=\"mailto:a@b.c\" target=\"_blank\" rel=\"noreferrer noopener\">x</a></b>"),
        ]
        for (line, html) in cases {
            #expect(inlineToHtml(escapeHtml(line)) == html)
        }
    }

    // From "inlineToHtml" (added on both apps with D-39): "escapes a link's
    // address once, so an & in it survives".
    @Test func escapesALinksAddressOnce() {
        let html = inlineToHtml(escapeHtml("[x](https://a.test/?p=1&q=2)"))
        #expect(html.contains("href=\"https://a.test/?p=1&amp;q=2\""))
        #expect(!html.contains("&amp;amp;"))
        #expect(inlineToHtml(escapeHtml("[](https://a.test/?p=1&q=2)")).contains(">https://a.test/?p=1&amp;q=2</a>"))
        // And the run opens the address as typed.
        #expect(noteRuns("[x](https://a.test/?p=1&q=2)") == [InlineRun(text: "x", link: "https://a.test/?p=1&q=2")])
    }

    // Phone-only: the web leaves a stray "0" here (its marker inside a marker).
    @Test func anEscapeInsideCodeComesBackAsTheCharacter() {
        #expect(inlineToHtml("`a\\*b`") == "<code>a*b</code>")
    }

    // Kelvin's (D-42).
    @Test func pastedControlCharactersDoNotIndexOutsideTheStash() {
        let text = "pasted \u{0}99\u{1} and \u{0}999999999999999999999999999\u{1}"
        #expect(inlineToHtml(text) == text)
        #expect(noteRuns(text) == [InlineRun(text: text)])
        #expect(noteRuns(text + " and `code`") == [
            InlineRun(text: text + " and "), InlineRun(text: "code", code: true),
        ])
    }

    @Test func safeHrefKeepsOnlyWebAndMailAddresses() {
        #expect(safeHref("  https://x.y ") == "https://x.y")
        #expect(safeHref("HTTP://x.y") == "HTTP://x.y")
        #expect(safeHref("mailto:a@b.c") == "mailto:a@b.c")
        #expect(safeHref("javascript:alert(1)") == nil)
        #expect(safeHref("ftp://x.y") == nil)
    }
}

@Suite struct InlineRunsTests {
    @Test func plainTextIsOneRun() {
        #expect(noteRuns("just words") == [InlineRun(text: "just words")])
        #expect(noteRuns("").isEmpty)
    }

    @Test func eachStyleIsItsOwnRun() {
        #expect(noteRuns("a **b** *c* __d__ ==e== `f`") == [
            InlineRun(text: "a "), InlineRun(text: "b", bold: true), InlineRun(text: " "),
            InlineRun(text: "c", italic: true), InlineRun(text: " "),
            InlineRun(text: "d", underline: true), InlineRun(text: " "),
            InlineRun(text: "e", highlight: true), InlineRun(text: " "),
            InlineRun(text: "f", code: true),
        ])
    }

    @Test func stylesNestAndCross() {
        #expect(noteRuns("[[blue|**due** friday]]") == [
            InlineRun(text: "due", bold: true, pen: "blue"),
            InlineRun(text: " friday", pen: "blue"),
        ])
        // The tags cross; each stretch keeps what's open over it.
        #expect(noteRuns("**a __b** c__") == [
            InlineRun(text: "a ", bold: true),
            InlineRun(text: "b", bold: true, underline: true),
            InlineRun(text: " c", underline: true),
        ])
    }

    @Test func linksCarryTheirAddress() {
        #expect(noteRuns("see [notes](https://x.y) now") == [
            InlineRun(text: "see "),
            InlineRun(text: "notes", link: "https://x.y"),
            InlineRun(text: " now"),
        ])
        // An unsafe link stays plain text.
        #expect(noteRuns("[a](javascript:alert(1))") == [InlineRun(text: "[a](javascript:alert(1))")])
    }

    @Test func entitiesComeBackAsCharacters() {
        #expect(noteRuns("a < b & \"c\" > d") == [InlineRun(text: "a < b & \"c\" > d")])
        #expect(noteRuns("`<b>`") == [InlineRun(text: "<b>", code: true)])
    }

    @Test func escapedMarkersAreJustCharacters() {
        #expect(noteRuns("\\*not italic\\*") == [InlineRun(text: "*not italic*")])
    }
}
