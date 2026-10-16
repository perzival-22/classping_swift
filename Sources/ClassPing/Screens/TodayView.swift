//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/TodayView.swift
//  Phase:   3 (app shell)
//  Ports:   app/home/page.tsx (placeholder; Phase 6 builds the real Today)
//
//  Summary: The Today tab. For now a welcome card plus a temporary Appearance
//           card, so you can watch dark mode and the accent switch live. Phase 6
//           replaces this with the next class, priorities, planned work and the
//           quote banner.
//

import SwiftUI

struct TodayView: View {
    @Environment(Store.self) private var store

    var body: some View {
        // `@Bindable` turns the observable store into something a Picker can bind
        // to, so `$store.profile.theme` is a two-way connection to that field.
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // A plain card, to show the surface and radius tokens on screen.
                VStack(alignment: .leading, spacing: 6) {
                    Text(greeting)
                        .font(.headline)
                        .foregroundStyle(Theme.ink)
                    Text("Your day's classes, priorities and planned work will appear here in Phase 6.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()

                // TEMPORARY. Phase 11 moves appearance into Settings; this card is
                // here only so dark mode and the accent can be exercised now.
                VStack(alignment: .leading, spacing: 12) {
                    Text("Appearance (temporary)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.faint)

                    Picker("Theme", selection: $store.profile.theme) {
                        Text("Light").tag(Profile.Theme.light)
                        Text("Dark").tag(Profile.Theme.dark)
                    }
                    .pickerStyle(.segmented)

                    Picker("Accent", selection: $store.profile.accent) {
                        Text("Baby Pink").tag(Profile.Accent.babypink)
                        Text("Ocean").tag(Profile.Accent.ocean)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle()
            }
            .padding(16)
        }
        .background(Theme.canvas)
        .navigationTitle("Today")
        // Save whenever any profile field changes, so the choice survives a relaunch.
        // Profile is Equatable, so onChange fires only on a real change.
        .onChange(of: store.profile) { store.save() }
    }

    /// "Welcome back" or "Welcome back, <name>" once a username exists.
    private var greeting: String {
        store.profile.username.isEmpty
            ? "Welcome back"
            : "Welcome back, \(store.profile.username)"
    }
}