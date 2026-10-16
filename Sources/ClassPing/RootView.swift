//
//  File:    ~/ClassPing/Sources/ClassPing/RootView.swift
//  Phase:   0 (housekeeping)
//  Ports:   components/TabBar.tsx (only two tabs for now; Phase 3 makes it four plus Add)
//
//  Summary: The screen under everything else: a tab bar that switches between
//           the Week and Tasks screens.
//
/// The App's main screen
/// Each tab getsd its own NavigationStack so it keeps its own back history
/// the way ewach web route keeps its own URL
import SwiftUI

enum MainTab: Hashable {case today, notes, planner, tasks}

struct RootView: View {
    //The shared store, for accent and theme the while app reads
    @Environment(Store.self) private var store

    // The selected tab and whether the Add menu is open "@state" means the view owns those values and redraws when the change

    @State private var tab: MainTab = .today
    @State private var addOpen = false

    var body: some View {
        //Read the accent once;
        let accent = store.profile.accent

        //The selected screen. Each tab keeps it own NavigationStack, keeping their own Back history.

        Group {
            switch tab {
            case .today:   NavigationStack { TodayView() }
            case .notes:   NavigationStack { NotesView() }
            case .planner: NavigationStack { WeekView().navigationTitle("Planner") }
            case .tasks:   NavigationStack { AssignmentsView().navigationTitle("Tasks") }
            }
        }
        // `safeAreaInset` pins the bar to the bottom and insets the screen above
        // it, so a list never scrolls underneath the bar.
        .safeAreaInset(edge: .bottom) {
            MainTabBar(tab: $tab, addOpen: $addOpen, accent: accent)
        }
        // The warm ground behind everything, including under the bar.
        .background(Theme.canvas.ignoresSafeArea())
        // The accent tints buttons, pickers and links app-wide.
        .tint(Theme.brand(accent))
        // Force light or dark to match the profile, overriding the system setting.
        .preferredColorScheme(store.profile.theme == .dark ? .dark : .light)
        // The Add button opens this sheet.
        .sheet(isPresented: $addOpen) { AddMenu() }
    }
}

/// The bottom bar: two tabs, the Add button, two tabs. A rounded "glass" pill
/// floating above the canvas, matching components/TabBar.tsx.
private struct MainTabBar: View {
    @Binding var tab: MainTab
    @Binding var addOpen: Bool
    let accent: Profile.Accent

    var body: some View {
        HStack(spacing: 0) {
            item(.today, "Today", "house.fill")
            item(.notes, "Notes", "book.fill")
            addButton
            item(.planner, "Planner", "calendar")
            item(.tasks, "Tasks", "checklist")
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 6)
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }

    /// One destination. Active gets the brand color, the rest stay faint, the
    /// same split the web bar makes with `--color-brand` vs `--color-faint`.
    private func item(_ which: MainTab, _ label: String, _ symbol: String) -> some View {
        let active = tab == which
        return Button {
            tab = which
        } label: {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 20))
                Text(label).font(.system(size: 10, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(active ? Theme.brand(accent) : Theme.faint)
        }
        .buttonStyle(.plain)
    }

    /// The raised brand circle in the middle. Opens the Add menu.
    private var addButton: some View {
        Button {
            addOpen = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(Theme.brandGradient(accent), in: Circle())
                .shadow(color: Theme.brand(accent).opacity(0.35), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .frame(width: 62)       // a fixed middle slot, so the two halves balance
        .offset(y: -14)         // lifted above the bar, like the web's -mt-6
    }
}
