//
// File: ~/ClassPing/Sources/ClassPing/Logic/ScaleDraft.swift
// Phase: 9b (scales, goals and what-if)
// Ports: components/GradeScaleEditor.tsx (DraftBand, toDraft, fromDraft and
//        PREVIEW_MARKS).
// Summary: The custom-scale editor's rows while you type. Numbers stay text,
//          so a half-typed "8" isn't read as 8 too early, and turning rows
//          back into bands is pure Foundation, so Linux tests can check it.
//
import Foundation

/// One band mid-edit. `DraftBand` in GradeScaleEditor.tsx.
/// `Identifiable` gives each row an id that never changes, so when you
/// remove row 2 SwiftUI removes that row, instead of deciding rows 2 to 16
/// all changed. `Hashable` lets `.onChange(of:)` compare two drafts.
struct ScaleDraftRow: Identifiable, Hashable {
    var id = UUID()
    var letter = ""
    var min = ""
    var points = ""
}

/// The marks "What this gives" runs through the scale. `PREVIEW_MARKS`.
let SCALE_PREVIEW_MARKS: [Double] = [95, 85, 72, 64, 45]

/// Saved bands as editable rows: `toDraft`. The numbers are written the
/// phone's way ("3.7", or "3,7" where a comma is the decimal mark), so the
/// field shows what the decimal keyboard would type.
func scaleDraftRows(from bands: [ScaleBand], locale: Locale = .current) -> [ScaleDraftRow] {
    bands.map { band in
        ScaleDraftRow(letter: band.letter,
                      min: band.min.formatted(.number.locale(locale).grouping(.never)),
                      points: band.points.formatted(.number.locale(locale).grouping(.never)))
    }
}

/// A field's text as a number, the way JavaScript's `Number()` reads it on
/// the web: blank is 0 and unreadable is NaN, which scaleIssues then names.
/// The phone's own decimal mark is accepted as well as a point.
func scaleNumber(_ text: String, locale: Locale = .current) -> Double {
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if value.isEmpty { return 0 }
    let mark = locale.decimalSeparator ?? "."
    return Double(value.replacingOccurrences(of: mark, with: ".")) ?? .nan
}

/// Rows back to bands, unchecked: `fromDraft`. Hand the result to
/// scaleIssues to explain it and to normalizeScale to keep what's usable.
func scaleBands(from rows: [ScaleDraftRow], locale: Locale = .current) -> [ScaleBand] {
    rows.map { row in
        ScaleBand(min: scaleNumber(row.min, locale: locale), letter: row.letter,
                  points: scaleNumber(row.points, locale: locale))
    }
}
