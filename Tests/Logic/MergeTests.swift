// MergeTests.swift: the Swift twin of lib/merge.test.ts, plus parity cases.
// Run: tools/logic-test.sh. Kelvin does not type this file.
import Foundation
import Testing
@testable import CPLogic

/// The web test's row: an id and a title.
private struct Row: Equatable {
    var id: String
    var title: String
}

/// `JSON.stringify(row)` on the web, written out by hand so the text (and so
/// the fingerprint) is exactly the web's: `{"id":"a","title":"Essay"}`.
private func json(_ r: Row) -> String {
    "{\"id\":\"\(r.id)\",\"title\":\"\(r.title)\"}"
}

/// The web's `snap(...rows)`: each row's fingerprint under its id.
private func snap(_ rows: Row...) -> [String: String] {
    var out: [String: String] = [:]
    for r in rows { out[r.id] = hashRow(json(r)) }
    return out
}

/// `mergeWithServer` with the test's id and text functions filled in.
private func merge(_ local: [Row], _ server: [Row], _ snapshot: [String: String]) -> MergeResult<Row> {
    mergeWithServer(local, server, snapshot: snapshot, id: { $0.id }, rowJSON: json)
}

@Suite struct MergeTests {
    // MARK: hashRow (the web's three cases)

    @Test func hashIsStableForTheSameInput() {
        #expect(hashRow("hello") == hashRow("hello"))
    }

    @Test func hashSeparatesInputsThatDifferByOneCharacter() {
        #expect(hashRow("Essay 1") != hashRow("Essay 2"))
    }

    @Test func hashHandlesEmptyInput() {
        #expect(!hashRow("").isEmpty)
    }

    // MARK: hashRow parity

    /// web: every fingerprint the web printed (WebValues14a.swift), emoji,
    /// accents, CRLF, a byte-order mark, NUL and 500 characters included.
    @Test func hashMatchesTheWebExactly() {
        for (input, hash) in WEB_HASHES {
            #expect(hashRow(input) == hash, "input: \(input.debugDescription)")
        }
    }

    /// web: a row's text as the merge fingerprints it.
    @Test func hashOfARowMatchesTheWeb() {
        let expected = WEB_HASHES.first { $0.input == "{\"id\":\"a\",\"title\":\"Essay\"}" }?.hash
        #expect(expected != nil)
        #expect(hashRow(json(Row(id: "a", title: "Essay"))) == expected)
    }

    // MARK: mergeWithServer (the web's eleven cases)

    @Test func keepsARowCreatedOfflineThatTheServerHasNeverSeen() {
        let local = [Row(id: "a", title: "Essay")]
        let result = merge(local, [], [:])
        #expect(result.merged == local)
        #expect(result.pending == ["a"])
        #expect(result.outcomes["a"] == .localNew)
    }

    @Test func dropsARowTheServerNoLongerHasWhenWeAgreedItExisted() {
        let row = Row(id: "a", title: "Essay")
        let result = merge([row], [], snap(row))
        #expect(result.merged == [])
        #expect(result.pending == [])
        #expect(result.outcomes["a"] == .removed)
    }

    @Test func takesARowCreatedOnAnotherDevice() {
        let theirs = Row(id: "b", title: "Lab report")
        let result = merge([], [theirs], [:])
        #expect(result.merged == [theirs])
        #expect(result.outcomes["b"] == .server)
    }

    @Test func takesTheServersVersionWhenOnlyTheServerMoved() {
        let base = Row(id: "a", title: "Essay")
        let theirs = Row(id: "a", title: "Essay (revised)")
        let result = merge([base], [theirs], snap(base))
        #expect(result.merged == [theirs])
        #expect(result.pending == [])
        #expect(result.outcomes["a"] == .server)
    }

    @Test func keepsTheLocalVersionAndMarksItPendingWhenOnlyWeMoved() {
        let base = Row(id: "a", title: "Essay")
        let mine = Row(id: "a", title: "Essay, final")
        let result = merge([mine], [base], snap(base))
        #expect(result.merged == [mine])
        #expect(result.pending == ["a"])
        #expect(result.outcomes["a"] == .local)
    }

    @Test func reportsAConflictLosingNeitherSideWhenBothMoved() {
        let base = Row(id: "a", title: "Lecture 4")
        let mine = Row(id: "a", title: "Lecture 4, my notes")
        let theirs = Row(id: "a", title: "Lecture 4, laptop notes")
        let result = merge([mine], [theirs], snap(base))
        #expect(result.outcomes["a"] == .conflict)
        #expect(result.conflicts.count == 1)
        #expect(result.conflicts.first?.id == "a")
        #expect(result.conflicts.first?.local == mine)
        #expect(result.conflicts.first?.server == theirs)
        // The server's row holds the id; the caller keeps ours separately.
        #expect(result.merged == [theirs])
    }

    @Test func treatsAMatchingRowAsSettledEvenWhenTheSnapshotIsStale() {
        let row = Row(id: "a", title: "Essay")
        let stale = ["a": hashRow(json(Row(id: "a", title: "old")))]
        let result = merge([row], [row], stale)
        #expect(result.outcomes["a"] == .server)
        #expect(result.pending == [])
    }

    @Test func callsADivergentRowWithNoCommonAncestorAConflictNotALoss() {
        let result = merge([Row(id: "a", title: "mine")], [Row(id: "a", title: "theirs")], [:])
        #expect(result.outcomes["a"] == .conflict)
        #expect(result.conflicts.count == 1)
    }

    @Test func handlesARealisticReconnect() {
        let kept = Row(id: "1", title: "Reading")
        let editedBase = Row(id: "2", title: "Essay")
        let editedLocal = Row(id: "2", title: "Essay draft 2")
        let madeOffline = Row(id: "3", title: "Lab prep")
        let goneElsewhere = Row(id: "4", title: "Old quiz")
        let result = merge(
            [kept, editedLocal, madeOffline, goneElsewhere],
            [kept, editedBase],
            snap(kept, editedBase, goneElsewhere))
        #expect(result.merged == [kept, editedLocal, madeOffline])
        #expect(result.pending.sorted() == ["2", "3"])
        #expect(result.outcomes["4"] == .removed)
        #expect(result.conflicts.isEmpty)
    }

    @Test func putsServerOrderFirstAndAppendsLocalOnlyRows() {
        let s1 = Row(id: "s1", title: "a")
        let s2 = Row(id: "s2", title: "b")
        let mine = Row(id: "m1", title: "c")
        let result = merge([mine, s2, s1], [s1, s2], [:])
        #expect(result.merged.map(\.id) == ["s1", "s2", "m1"])
    }

    @Test func isIdempotentOnceBothSidesAgree() {
        let rows = [Row(id: "a", title: "Essay")]
        let first = merge(rows, rows, snap(rows[0]))
        let second = merge(first.merged, rows, snap(rows[0]))
        #expect(second.merged == first.merged)
        #expect(second.pending == [])
        #expect(second.conflicts.isEmpty)
    }

    // MARK: the web's Map rule for a repeated id

    /// A JavaScript Map keeps a key where it first appeared and the value
    /// last set for it. The merge reads both lists that way.
    @Test func aRepeatedIdKeepsItsFirstPlaceAndItsLastValue() {
        let first = Row(id: "s1", title: "first")
        let last = Row(id: "s1", title: "last")
        let other = Row(id: "s2", title: "other")
        let result = merge([], [first, other, last], [:])
        #expect(result.merged == [last, other])
    }

    // MARK: snapshot serialisation (the web's two cases)

    @Test func snapshotRoundTripsThroughJSON() {
        let map = ["a": "hash-a", "b": "hash-b"]
        let data = (try? JSONEncoder().encode(snapshotToJSON(map))) ?? Data()
        let back = try? JSONDecoder().decode(JSONValue.self, from: data)
        #expect(snapshotFromJSON(back) == map)
    }

    @Test func snapshotSurvivesACorruptOrAbsentStoredValue() {
        let bad: [JSONValue?] = [.null, nil, .string("nope"), .number(42), .array([]),
                                 .object(["a": .number(1)])]
        for value in bad {
            #expect(snapshotFromJSON(value) == [:])
        }
        #expect(snapshotFromJSON(.object(["a": .number(1), "b": .string("ok")])) == ["b": "ok"])
    }
}
