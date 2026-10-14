//
//  File:    ~/ClassPing/Sources/ClassPing/RootView.swift
//  Phase:   0 (housekeeping)
//  Ports:   components/TabBar.tsx (only two tabs for now; Phase 3 makes it four plus Add)
//
//  Summary: The screen under everything else: a tab bar that switches between
//           the Week and Tasks screens.
//
import SwiftUI

/// The App's main screen
/// Each tab getsd its own NavigationStack so it keeps its own back history
/// the way ewach web route keeps its own URL
struct RootView: View {
    var body: some View {
        TabView {
            Tab("Week", systemImage: "calendar") {
                NavigationStack { WeekView().navigationTitle("This Week")}
            }
            Tab("Tasks", systemImage: "checklist") {
                NavigationStack { AssignmentsView().navigationTitle("Tasks")}
            }
        }
    }
}
