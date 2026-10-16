//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/NotesView.swift
//  Phase:   3 (app shell)
//  Ports:   app/classes/page.tsx (placeholder; Phase 8 builds the real Notes)
//
//  Summary: The Notes tab. A themed placeholder until Phase 8 builds the subject
//           list, the reader and the markdown editor.
//

import SwiftUI

struct NotesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("Your classes and their notes will live here.")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text("Phase 8 builds the notes reader and editor.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle()
            .padding(16)
        }
        .background(Theme.canvas)
        .navigationTitle("Notes")
    }
}