//
//  File:    ~/ClassPing/Sources/ClassPing/RootView.swift
//  Phase:   3 (app shell), changed in 5a (Profile tab replaces Planner, D-19),
//           6b (Today can switch tabs), 7c (going where a tap asks),
//           after 8c (the bar steps aside for the keyboard, D-43) and in
//           8d (the Add menu can switch tabs too, for Note)
//  Ports:   components/TabBar.tsx (four tabs with the Add button between them),
//           and openApp() in public/sw.js (a tap opens the right screen)
//
//  Summary: The screen under everything else. A custom bottom bar switches
//           between the four main screens, Today, Notes, Tasks and Profile,
//           with the brand Add button raised in the middle. The week now lives
//           inside Today. The whole app is tinted with the chosen accent and
//           forced to the chosen light/dark mode here. Since 7c it also takes
//           the store's route: a task's detail, Today, or the post-class
//           prompt, which it shows over everything.
//

import SwiftUI

/// Which of the four main tabs is showing. In the web app this is the current
/// `pathname`; here it is one piece of state the bar reads and writes.
// CHANGED in Phase 5a: `planner` is gone (the week is inside Today), `profile` is new
enum MainTab: Hashable { case today, notes, tasks, profile }

struct RootView: View {
    /// The shared store, for the accent and theme the whole app reads.
    @Environment(Store.self) private var store

    /// The selected tab, and whether the Add menu is open. `@State` means this
    /// view owns these values and redraws when they change.
    @State private var tab: MainTab = .today
    @State private var addOpen = false

    /// NEW in Phase 7c: what's pushed on the Tasks tab, in code. A
    /// `NavigationPath` is a navigation stack written as a list: empty is the
    /// task list itself; one `AssignmentLink` in it is that task's detail on
    /// top. Tapping a row still adds to it by itself; a tap on a notification
    /// replaces it.
    @State private var tasksPath = NavigationPath()

    /// NEW in Phase 7c: whether the post-class prompt is showing, and which
    /// class it asks about (nil: none just ended, so it says so).
    @State private var promptOpen = false
    @State private var promptCourse: Course? = nil

    /// NEW in Phase 7c: the class a new task starts on after "Yes, add it".
    /// While it's set, the task form is open in a sheet.
    @State private var addingFor: Course? = nil

    /// NEW after Phase 8c (D-43): true while the keyboard is on screen. The
    /// bar steps aside then, so nothing that sits on the keyboard (the note's
    /// formatting bar, the end of a search's results) is hidden behind it.
    @State private var keyboardUp = false

    var body: some View {
        // Read the accent once; reading it here means the whole screen redraws
        // (new tint, new bar colors) the moment it changes in Profile.
        let accent = store.profile.accent

        // TabView keeps each screen and its navigation history alive when
        // switching tabs, including the selected day and expanded week.
        TabView(selection: $tab) {
            // CHANGED in Phase 6b: Today gets the tab, for "View all".
            NavigationStack { TodayView(tab: $tab) }
                .toolbar(.hidden, for: .tabBar)
                .tag(MainTab.today)
            NavigationStack { NotesView() }
                .toolbar(.hidden, for: .tabBar)
                .tag(MainTab.notes)
            // CHANGED in Phase 7c: `path:` lets a tap open a task's detail.
            NavigationStack(path: $tasksPath) { AssignmentsView().navigationTitle("Tasks") }
                .toolbar(.hidden, for: .tabBar)
                .tag(MainTab.tasks)
            NavigationStack { ProfileView() }
                .toolbar(.hidden, for: .tabBar)
                .tag(MainTab.profile)
        }
        // `safeAreaInset` pins the bar to the bottom and insets the screen above
        // it, so a list never scrolls underneath the bar.
        .safeAreaInset(edge: .bottom) {
            // CHANGED after Phase 8c (D-43): gone while the keyboard is up.
            if !keyboardUp {
                MainTabBar(tab: $tab, addOpen: $addOpen, accent: accent,
                           name: store.profile.username)
            }
        }
        // NEW after Phase 8c (D-43): iOS announces the keyboard coming and going.
        // `onReceive` runs its closure each time one of those arrives.
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardUp = true
        }
        .onReceive(NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardUp = false
        }
        // The warm ground behind everything, including under the bar.
        .background(Theme.canvas.ignoresSafeArea())
        // The accent tints buttons, pickers and links app-wide.
        .tint(Theme.brand(accent))
        // Force light or dark to match the profile, overriding the system setting.
        .preferredColorScheme(store.profile.theme == .dark ? .dark : .light)
        // NEW in Phase 7c: the post-class prompt, over the whole screen, tab
        // bar included. An overlay, not a sheet: a sheet can't open while
        // another one is showing, so a tap would get lost; an overlay always
        // appears, and at worst waits under a sheet you still have open.
        .overlay {
            ZStack {
                if promptOpen {
                    PostClassPrompt(course: promptCourse,
                                    onAdd: { course in
                                        promptOpen = false
                                        addingFor = course
                                    },
                                    onClose: {
                                        promptOpen = false
                                        tab = .today
                                    })
                        .transition(.opacity)
                }
            }
            // Fade the prompt in and out instead of popping. On the ZStack,
            // so only the prompt animates, not the tab switch behind it.
            .animation(.easeOut(duration: 0.2), value: promptOpen)
        }
        // The Add button opens this sheet.
        // CHANGED in Phase 8d: with the tab, so Note can switch to Notes.
        .sheet(isPresented: $addOpen) { AddMenu(tab: $tab) }
        // NEW in Phase 7c: "Yes, add it" opens the task form on that class.
        // `sheet(item:)` shows it while `addingFor` is set and clears it on close.
        .sheet(item: $addingFor) { course in
            NavigationStack {
                AssignmentFormView(courseID: course.id, onFinish: { addingFor = nil })
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { addingFor = nil }
                        }
                    }
            }
        }
        // NEW in Phase 7c: go where a tapped notification or "Log it" asked.
        // `initial: true` also runs this when the screen first appears, for a
        // tap that launched the app before this screen existed.
        .onChange(of: store.route, initial: true) { _, route in
            guard let route else { return }
            go(route)
            // Taken. Back to nil, so the same request again still counts as a change.
            store.route = nil
        }
    }

    /// Opens the screen a route names. NEW in Phase 7c. Nothing you have open
    /// is closed: if a sheet is showing, the screen waits underneath it.
    private func go(_ route: AppRoute) {
        switch route {
        case .today:
            tab = .today
        case .task(let id):
            tab = .tasks
            // The list with that task's detail on top, or just the list if
            // the task was deleted since the notification was planned.
            tasksPath = store.assignment(id) == nil
                ? NavigationPath()
                : NavigationPath([AssignmentLink(id: id)])
        case .postClass(let id):
            // The class the notification names, which stays right even if
            // you tap it an hour later; else whichever class just ended.
            promptCourse = store.course(id) ?? justEnded(store.activeCourses, now: .now)?.course
            promptOpen = true
        }
    }
}

/// The bottom bar: two tabs, the Add button, two tabs. A rounded "glass" pill
/// floating above the canvas, matching components/TabBar.tsx.
private struct MainTabBar: View {
    @Binding var tab: MainTab
    @Binding var addOpen: Bool
    let accent: Profile.Accent
    /// Your username, for the letter on the Profile avatar. NEW in Phase 5a
    let name: String

    var body: some View {
        HStack(spacing: 0) {
            item(.today, "Today", "house.fill")
            item(.notes, "Notes", "book.fill")
            addButton
            item(.tasks, "Tasks", "checklist")      // CHANGED in Phase 5a: Planner removed
            profileItem                              // NEW in Phase 5a
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
                Image(systemName: symbol)
                    .font(.system(size: 20))
                    .frame(height: 26)      // CHANGED in Phase 5a: as tall as the avatar
                Text(label).font(.system(size: 10, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(active ? Theme.brand(accent) : Theme.faint)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    /// The Profile tab: your avatar instead of an icon, with a brand ring
    /// around it while the tab is open. (Phase 12 swaps that ring for your
    /// pet's tier ring, which used to sit on the + button on the web.)
    // NEW in Phase 5a
    private var profileItem: some View {
        let active = tab == .profile
        let brand = Theme.brand(accent)
        return Button {
            tab = .profile
        } label: {
            VStack(spacing: 4) {
                AvatarBadge(name: name, size: 22, accent: accent)
                    .padding(2)
                    .overlay(Circle().stroke(active ? brand : Color.clear, lineWidth: 1.5))
                Text("Profile").font(.system(size: 10, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(active ? brand : Theme.faint)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile")
        .accessibilityAddTraits(active ? .isSelected : [])
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
        .accessibilityLabel("Add")
        .frame(width: 62)       // a fixed middle slot, so the two halves balance
        .offset(y: -14)         // lifted above the bar, like the web's -mt-6
    }
}
