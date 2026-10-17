//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Today/QuoteBanner.swift
//  Phase:   6a (Today: the picked day)
//  Ports:   components/QuoteBanner.tsx
//
//  Summary: The banner at the top of Today: one motivational line that
//           changes every two hours. The pencil opens an editor where you can
//           write your own list, one per line; an empty list goes back to the
//           built-in rotation. Your list is saved on your profile.
//

import SwiftUI

struct QuoteBanner: View {
    @Environment(Store.self) private var store

    /// The moment to pick a quote for, from Today's ticking clock.
    let now: Date

    /// Showing the editor instead of the quote, and the text being edited.
    @State private var editing = false
    @State private var draft = ""

    /// Whether the editor's text field has the keyboard. `@FocusState` is a
    /// property SwiftUI keeps in step with the keyboard: set it to true and
    /// the field it's attached to (with `.focused`) gets the cursor and the
    /// keyboard comes up; tap elsewhere and SwiftUI sets it back to false.
    /// The web does the same with `autoFocus` on the textarea.
    @FocusState private var fieldFocused: Bool

    var body: some View {
        let quotes = store.profile.quotes
        let accent = store.profile.accent

        // `Group` lets an if/else return two different views under one set
        // of modifiers: the same padding and background for both.
        Group {
            if editing {
                editor(accent)
            } else {
                reader(quotes, accent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 6)
    }

    // MARK: - Reading

    /// The quote, its small heading and the pencil.
    private func reader(_ quotes: [String], _ accent: Profile.Accent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                // "Your reminder" once you've written your own.
                Text((quotes.isEmpty ? "A little push" : "Your reminder").uppercased())
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Theme.faint)
                Text(quoteFor(quotes, now))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(3)
                    // Wrap onto as many lines as it needs instead of "...".
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                openEditor(quotes)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.brand(accent))
                    .frame(width: 32, height: 32)
                    .background(Theme.brandSoft(accent), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit my quotes")
        }
    }

    // MARK: - Editing

    /// The list as text, one quote per line, with Cancel and Save.
    private func editor(_ accent: Profile.Accent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("YOUR QUOTES")
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(Theme.faint)
                Spacer()
                Text("One per line")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.hint)
            }

            // `axis: .vertical` turns a one-line TextField into one that grows
            // downwards as you type, and Return adds a new line instead of
            // finishing. `lineLimit(5...10)` means: at least 5 lines tall, and
            // scroll inside once it reaches 10.
            TextField("Write a line that keeps you going.\nAdd as many as you like.",
                      text: $draft, axis: .vertical)
                .lineLimit(5...10)
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink)
                .focused($fieldFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityLabel("Your motivational quotes, one per line")
                // Put the cursor in the field as soon as it appears.
                .onAppear { fieldFocused = true }

            Text("Up to \(maxQuotes). Leave it empty to use our rotation. They change every two hours.")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            if store.lastSaveFailed {
                Text("Couldn't save on this device. Try Save quotes again.")
                    .font(.footnote)
                    .foregroundStyle(Theme.dangerInk)
            }

            HStack(spacing: 8) {
                Button {
                    fieldFocused = false
                    editing = false
                } label: {
                    Text("Cancel")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
                Button {
                    save()
                } label: {
                    Text("Save quotes")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background(Theme.brandGradient(accent), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions

    /// Fills the editor with your current list, one per line, and shows it.
    private func openEditor(_ quotes: [String]) {
        draft = quotes.joined(separator: "\n")
        editing = true
    }

    /// Splits the text into lines, cleans them with the ported
    /// `normalizeQuotes`, and saves them to your profile. `setProfile({ quotes })`
    /// on the web. Saving straight away keeps "Saved on this device" honest.
    private func save() {
        store.profile.quotes = normalizeQuotes(draft.components(separatedBy: "\n"))
        store.save()
        guard !store.lastSaveFailed else { return }
        fieldFocused = false
        editing = false
    }
}
