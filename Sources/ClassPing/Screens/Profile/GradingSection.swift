//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Profile/GradingSection.swift
//  Phase:   11a (settings), moved here from 9b's Grades screen (D-67)
//  Ports:   the grading card of app/settings/page.tsx
//
//  Summary: The Grading scale card in the Profile tab: A / A−, A / B / C or
//           Custom, a line about each, and for Custom the way into 9b's
//           scale editor. Moved, not changed: the same code that sat on the
//           Grades screen until there was a Settings to put it in (D-51).
//

import SwiftUI

struct GradingSection: View {
    @Environment(Store.self) private var store

    var body: some View {
        let selected = store.profile.gradeScale ?? .standard

        VStack(alignment: .leading, spacing: 10) {
            Text("GRADING SCALE")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.faint)
                .accessibilityAddTraits(.isHeader)
            // The choice goes through the store, which puts the old one back
            // if the write fails (D-53).
            Picker("Grade scale", selection: Binding(
                get: { store.profile.gradeScale ?? .standard },
                set: { store.setGradeScale($0) }
            )) {
                Text("A / A\u{2212}").tag(Profile.GradeScale.standard)
                Text("A / B / C").tag(Profile.GradeScale.simple)
                Text("Custom").tag(Profile.GradeScale.custom)
            }
            .pickerStyle(.segmented)

            // A line about the chosen scale; Custom adds the way into its editor.
            switch selected {
            case .standard:
                Text("93+ is an A, 90+ an A\u{2212}. The usual US scale.")
                    .font(.footnote).foregroundStyle(Theme.muted)
            case .simple:
                Text("90+ is an A, 80+ a B. No plus or minus bands.")
                    .font(.footnote).foregroundStyle(Theme.muted)
            case .custom:
                Text(store.usesFallbackScale
                     ? "Your custom scale is empty. Using US 4.0 for now."
                     : "Using your \(store.gradeScale.count) bands.")
                    .font(.footnote).foregroundStyle(Theme.muted)
                NavigationLink {
                    GradeScaleEditor(saved: store.profile.customScale)
                } label: {
                    HStack {
                        Text(store.usesFallbackScale ? "Set up your scale" : "Edit your scale")
                        Spacer()
                        Image(systemName: "chevron.right").accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}
