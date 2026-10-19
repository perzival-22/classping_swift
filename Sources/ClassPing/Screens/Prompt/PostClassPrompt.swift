//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Prompt/PostClassPrompt.swift
//  Phase:   7c (taps and the post-class prompt)
//  Ports:   app/prompt/page.tsx (PostClassPrompt, SignedOff, NothingJustEnded)
//
//  Summary: The question asked right after a class: "Did this class come with
//           an assignment?". Yes opens the task form with that class picked;
//           No says what's next today. A card over a dimmed screen, like the
//           web's modal. RootView shows it for a tapped "just ended"
//           notification or for Today's Log it.
//

import SwiftUI
import UIKit

/// Two colors only this screen uses. `private` on an extension (7b's
/// file-level `private`) keeps them out of the rest of the app.
private extension Theme {
    /// The chat icon and the "… JUST ENDED" line. `--color-poli`, one shade
    /// in both modes.
    static let poli = Color(hex: "#C99C8D")
    /// The tile behind the 🎉. `--good-soft`: a solid light shade, and in dark
    /// mode a see-through green, which a hex string can't write.
    static let goodSoft = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 159 / 255, green: 187 / 255, blue: 138 / 255, alpha: 0.16)
            : UIColor(hex: "#DFE7D8")
    })
}

struct PostClassPrompt: View {
    @Environment(Store.self) private var store

    /// The class being asked about, or nil when none just ended (say, a late
    /// tap on a class that has since been deleted).
    let course: Course?
    /// "Yes, add it". RootView closes the prompt and opens the form for the class.
    let onAdd: (Course) -> Void
    /// "Back to Home". RootView closes the prompt and shows Today.
    let onClose: () -> Void

    /// True after "No, I'm good": the card becomes the sign-off. The web's
    /// `dismissed`.
    @State private var answeredNo = false

    var body: some View {
        let accent = store.profile.accent

        ZStack {
            // The dim layer behind the card, the web's rgba(30,22,60,.42). A
            // colored view on top catches touches, so nothing behind it can
            // be pressed by accident while the question is open.
            Color(red: 30 / 255, green: 22 / 255, blue: 60 / 255)
                .opacity(0.42)
                .ignoresSafeArea()

            // One card, three possible contents, in the web's order of checks.
            VStack(spacing: 0) {
                if let course, !answeredNo {
                    question(course, accent)
                } else if course != nil {
                    signedOff(accent)
                } else {
                    nothingEnded(accent)
                }
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 30, x: 0, y: 15)
            .padding(.horizontal, 24)
        }
        // To VoiceOver this is a dialog: it reads the card and nothing behind it.
        .accessibilityAddTraits(.isModal)
    }

    // MARK: - The three cards

    /// The question itself. `PostClassPrompt` in app/prompt/page.tsx.
    private func question(_ course: Course, _ accent: Profile.Accent) -> some View {
        VStack(spacing: 0) {
            tile(Image(systemName: "bubble.left.fill").font(.system(size: 30)).foregroundStyle(Theme.poli),
                 size: 66, radius: 20, color: Theme.dangerSoft)
            Text("\(course.name.uppercased()) JUST ENDED")
                .font(.system(size: 13, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.poli)
                .padding(.top, 16)
            Text("Did this class come with an assignment?")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 8)
            Text("Log it now while it's fresh, we'll keep you on track.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted2)
                .padding(.top, 8)

            VStack(spacing: 10) {
                // Straight into the task form, with this class picked.
                Button {
                    onAdd(course)
                } label: {
                    Text("Yes, add it")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Theme.brandGradient(accent),
                                    in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)
                // No: the card says so and points at what's next.
                Button {
                    answeredNo = true
                } label: {
                    Text("No, I'm good")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(Theme.surface2,
                                    in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 22)
        }
    }

    /// The "No" answer: say something, and point at the next class today so
    /// the card does a small job instead of just closing. `SignedOff`.
    private func signedOff(_ accent: Profile.Accent) -> some View {
        // Worked out when the card is drawn, from the classes on your timetable.
        let next = nextClassToday(store.activeCourses, now: .now)
        return VStack(spacing: 0) {
            tile(Text("🎉").font(.system(size: 34)), size: 72, radius: 24, color: Theme.goodSoft)
            Text("Nice, nothing to log")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 20)
            Text(next.map { "Enjoy \($0.course.name) at \(fmtTime($0.meeting.start)) 👋" }
                 ?? "That's you done. Have a great rest of your day 👋")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .padding(.top, 8)
            homeButton(accent)
        }
    }

    /// Nothing to ask about: no class ended recently. `NothingJustEnded`.
    private func nothingEnded(_ accent: Profile.Accent) -> some View {
        VStack(spacing: 0) {
            tile(Image(systemName: "bubble.left.fill").font(.system(size: 32)).foregroundStyle(Theme.poli),
                 size: 72, radius: 24, color: Theme.dangerSoft)
            Text("No class just ended")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.top, 20)
            Text("This nudge shows up right after one of your classes finishes, so you can log an assignment while it's still fresh.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.muted)
                .padding(.top, 8)
            homeButton(accent)
        }
    }

    // MARK: - Pieces

    /// The rounded square at the top of each card, holding an icon or an emoji.
    /// `some View` as a parameter type: the caller can hand in any view.
    private func tile(_ content: some View, size: CGFloat, radius: CGFloat, color: Color) -> some View {
        content
            .frame(width: size, height: size)
            .background(color, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// "Back to Home", under the sign-off and the "nothing" card.
    private func homeButton(_ accent: Profile.Accent) -> some View {
        Button {
            onClose()
        } label: {
            Text("Back to Home")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Theme.brandGradient(accent),
                            in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.top, 24)
    }
}
