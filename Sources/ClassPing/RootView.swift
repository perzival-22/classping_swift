import SwiftUI

/// The App's main screen
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
