//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Profile/ReviewCard.swift
//  Phase:   14e (signed-in server calls)
//  Ports:   components/ReviewCard.tsx and its route, app/api/feedback
//
//  Summary: "Rate ClassPing": one to five stars and an optional comment,
//           emailed straight to the student who builds the app, with your
//           username on it. Only shown signed in: the server takes the
//           phone's message on the strength of its sign-in, where a browser
//           would show which site it came from (D-103).
//

import SwiftUI

struct ReviewCard: View {
    @Environment(Store.self) private var store

    /// Where the card is: picking, sending, sent, or a failure to show.
    private enum Status: Equatable {
        case idle, sending, sent
        case error(String)
    }

    /// The stars picked, 0 for none yet.
    @State private var rating = 0
    @State private var message = ""
    @State private var status = Status.idle

    var body: some View {
        let accent = store.profile.accent

        VStack(alignment: .leading, spacing: 12) {
            if status == .sent {
                thanks(accent)
            } else {
                form(accent)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: - Pieces

    /// The stars, the comment and Send.
    @ViewBuilder
    private func form(_ accent: Profile.Accent) -> some View {
        Text("RATE CLASSPING")
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(Theme.faint)
            .accessibilityAddTraits(.isHeader)
        Text("Enjoying the app? Drop a rating.")
            .font(.system(size: 13))
            .foregroundStyle(Theme.muted)

        // Five stars; the picked one and those before it are filled, and the
        // word for the score follows them.
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { n in
                Button {
                    rating = n
                    status = .idle
                } label: {
                    Image(systemName: n <= rating ? "star.fill" : "star")
                        .font(.system(size: 28))
                        .foregroundStyle(n <= rating ? Theme.subject(.amber) : Theme.hint)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(n) \(n == 1 ? "star" : "stars")")
                .accessibilityAddTraits(rating == n ? .isSelected : [])
            }
            if rating > 0 {
                Text(reviewWord(rating))
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
        }

        VStack(alignment: .leading, spacing: 4) {
            Text("COMMENT (OPTIONAL)")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.faint)
            // `axis: .vertical` lets the field grow onto new lines.
            TextField("What's working for you, or not?", text: $message, axis: .vertical)
                .lineLimit(4...8)
                .font(.system(size: 16))
                .inputField(accent)
                .onChange(of: message) {
                    // The web's box stops at 4,000 characters.
                    if message.count > 4000 { message = String(message.prefix(4000)) }
                    if case .error = status { status = .idle }
                }
        }

        if case .error(let words) = status {
            Text(words)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.danger)
        }

        Button { Task { await send() } } label: {
            Text(status == .sending ? "Sending…" : rating == 0 ? "Pick a rating" : "Send review")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.brand(accent))
        .disabled(rating == 0 || status == .sending)

        Text("Goes straight to the student who builds ClassPing.")
            .font(.system(size: 12))
            .foregroundStyle(Theme.faint)
            .frame(maxWidth: .infinity)
    }

    /// After it sent: thanks, and a way to leave another.
    @ViewBuilder
    private func thanks(_ accent: Profile.Accent) -> some View {
        VStack(spacing: 6) {
            Text("🎉").font(.system(size: 34))
            Text("Thank you!")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text("Your \(rating)-star review landed in my inbox. It genuinely shapes what gets built next.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("Leave another") {
                rating = 0
                message = ""
                status = .idle
            }
            .font(.system(size: 14, weight: .semibold))
            .buttonStyle(.bordered)
            .tint(Theme.brand(accent))
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sending

    /// Sends the stars and comment, with your username. `submit`.
    private func send() async {
        guard rating > 0, status != .sending else { return }
        status = .sending
        let reply = await WebAPI.sendReview(rating: rating, message: message,
                                            name: store.profile.username)
        status = reply.ok ? .sent : .error(reviewProblem(reply))
    }
}
