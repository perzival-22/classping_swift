//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Grades/TermReportCard.swift
//  Phase:   9c (finals countdown and the CSV report), changed in 9b+
//           (a byte-order mark for Excel)
//  Ports:   ExportReportButton in app/grades/page.tsx (its CSV half) and
//           downloadGradeReport in lib/report.ts
//
//  Summary: The Term report card on Grades. One button opens the share sheet
//           with classping-grades.csv, built on the phone from this term's
//           classes and results: save it to Files, mail it, or AirDrop it.
//           The printable PDF is made by the server, so it waits for sign-in
//           (D-6).
//

import SwiftUI
import UniformTypeIdentifiers

/// The report as something the share sheet can send: a .csv file.
/// `Transferable` is how a value tells iOS what it can become (text, an
/// image, a file). On the web, `downloadBlob` in lib/report.ts does this job.
struct GradeReportFile: Transferable {
    /// This term's classes, results and scale, copied when the card was drawn.
    let report: TermReport

    /// The one form it can take: a file of type CSV (`.commaSeparatedText`).
    static var transferRepresentation: some TransferRepresentation {
        // FileRepresentation runs this only once you pick where the report
        // goes, so the file is built, and dated, at the moment you share it.
        FileRepresentation(exportedContentType: .commaSeparatedText) { file in
            // The app's temporary folder, which iOS empties on its own. The
            // file name is the one the web downloads.
            let url = URL.temporaryDirectory.appending(path: "classping-grades.csv")
            // CHANGED in Phase 9b+: "\u{FEFF}" first, the byte-order mark.
            // Excel on Windows reads a CSV without it in the old local code
            // page and garbles accented names; Numbers and Sheets skip it.
            // The web's `gradeReportBlob` adds the same three bytes.
            let data = Data(("\u{FEFF}" + file.report.csv(at: .now)).utf8)
            // `try?` turns a failed write into nil. This closure is allowed to
            // throw, and throwing tells the share sheet the file couldn't be
            // made, instead of handing over one that isn't there.
            guard (try? data.write(to: url, options: .atomic)) != nil else {
                throw CocoaError(.fileWriteUnknown)
            }
            return SentTransferredFile(url)
        }
    }
}

struct TermReportCard: View {
    @Environment(Store.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TERM REPORT")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
                .accessibilityAddTraits(.isHeader)

            // ShareLink is a button that opens the share sheet with `item`.
            // SharePreview is the title and icon at the top of that sheet.
            ShareLink(item: GradeReportFile(report: store.termReport),
                      preview: SharePreview("ClassPing grade report",
                                            image: Image(systemName: "tablecells"))) {
                Label("Share as a spreadsheet (CSV)", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)

            Text("Every result with its class, a summary for each class and your GPA. Opens in Numbers, Google Sheets or Excel.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
            Text("The printable PDF report needs sign-in, which comes later.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
