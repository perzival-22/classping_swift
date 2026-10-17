//
//  File:    ~/ClassPing/Sources/ClassPing/Components/UndoBar.swift
//  Phase:   4b (the Tasks screen); Today uses it too from Phase 6b
//  Ports:   components/StatusChrome.tsx (the undo strip) and the
//           UNDO_WINDOW_MS timer in lib/store.tsx
//
//  Summary: The bar that offers to take a delete back, packaged as a view
//           modifier. A screen that can delete things adds `.undoBar()`: the
//           bar sits above the tab bar while there's a delete to undo, and
//           goes away by itself 8 seconds later.
//

import SwiftUI

/// The Undo bar and its 8-second timer. In Phase 3, `.cardStyle()` was a
/// modifier written as a plain function; this one is a `ViewModifier`
/// struct instead, because it needs things a function can't hold: the store
/// from the environment, and a `.task` that lives as long as the screen.
/// `body(content:)` gets the screen it's attached to as `content` and
/// returns that screen with the bar and the timer added.
struct UndoBar: ViewModifier {
    @Environment(Store.self) private var store

    func body(content: Content) -> some View {
        content
            // The bar sits just above the tab bar while there's a delete to undo.
            .safeAreaInset(edge: .bottom) {
                if let undo = store.pendingUndo {
                    bar(undo, store.profile.accent)
                }
            }
            // Make the offer go away 8 seconds after the delete (UNDO_WINDOW_MS).
            // `.task(id:)` runs this async work when the view appears and again
            // whenever `id` changes, and cancels it when the view goes away.
            .task(id: store.pendingUndo?.at) {
                guard let undo = store.pendingUndo else { return }
                // Whatever is left of the 8 seconds (none, if we come back later).
                let left = max(0, 8 - Date.now.timeIntervalSince(undo.at))
                // `Task` here is Swift's own concurrency type, which is exactly why
                // the model can't be called Task. `try?` because sleeping throws
                // when the work is cancelled, and a cancel is not an error here.
                try? await Task.sleep(for: .seconds(left))
                // Cancelled (you left the screen, or a newer delete replaced this
                // one)? Leave the offer alone; the next run of this block decides.
                guard !Task.isCancelled else { return }
                if store.pendingUndo?.at == undo.at { store.dismissUndo() }
            }
    }

    /// The bar itself: what went, Undo, and a close button.
    private func bar(_ undo: PendingUndo, _ accent: Profile.Accent) -> some View {
        HStack(spacing: 12) {
            Text(undo.label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            Spacer()
            Button("Undo") { store.undoDelete() }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.brand(accent))
            Button {
                store.dismissUndo()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.faint)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .cardStyle()
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
    }
}

extension View {
    /// Adds the Undo bar to a screen: `SomeScreen().undoBar()`. A one-line
    /// wrapper, so callers don't have to write `.modifier(UndoBar())`.
    func undoBar() -> some View {
        modifier(UndoBar())
    }
}
