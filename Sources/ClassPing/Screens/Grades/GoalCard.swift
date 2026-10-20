//
// File: ~/ClassPing/Sources/ClassPing/Screens/Grades/GoalCard.swift
// Phase: 9b (scales, goals and what-if)
// Ports: GoalBlock in app/grades/page.tsx.
// Summary: A class's target grade and what it will take to get there. Pick a
//          goal from the top bands of your scale, then read what you need on
//          the work that's left, or why there's nothing left to work out.
//
import SwiftUI

/// Sits in a current-term class's card on the Grades screen, under its
/// average. The goal is saved on the class, not held in this view, because
/// the projected GPA at the top of the screen reads it too.
struct GoalCard: View {
    @Environment(Store.self) private var store
    let course: Course
    /// This class's live grades (its card already has them).
    let grades: [Grade]

    /// True while choosing a new goal over an existing one.
    @State private var picking = false
    /// Set when the last goal couldn't be written to planner.json.
    @State private var failed = false

    var body: some View {
        let goal = goalOf(course)
        let accent = Theme.brand(store.profile.accent)
        VStack(alignment: .leading, spacing: 8) {
            // The label, and the goal as a pill that reopens the chips.
            HStack {
                Text(goal == nil ? "Aiming for" : "Goal")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                Spacer(minLength: 8)
                if let goal, !picking {
                    Button { picking = true } label: {
                        HStack(spacing: 6) {
                            Text("\(letterFor(goal, store.gradeScale)) · \(goal.formatted())%")
                            Image(systemName: "pencil").imageScale(.small)
                        }
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(accent, in: Capsule())
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Goal \(letterFor(goal, store.gradeScale)), \(goal.formatted()) percent")
                    .accessibilityHint("Change the goal")
                }
            }

            // Chips stay open until a goal exists; after that, the pill opens them.
            if picking || goal == nil {
                chips(goal)
            }

            message(goal, accent: accent)
                .font(.footnote)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            if failed {
                Text("Couldn't save the goal on this device. Tap it again to retry.")
                    .font(.footnote)
                    .foregroundStyle(Theme.danger)
            }
        }
        .padding(12)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// The top five bands of your scale as chips, so a goal reads as a real
    /// grade ("A-") rather than a bare number. Tapping the active one clears it.
    private func chips(_ goal: Double?) -> some View {
        let bands = Array(store.gradeScale.sorted { $0.min > $1.min }.prefix(5))
        // `ViewThatFits` shows the first child that fits the width it's offered:
        // one plain row when the letters are short, a row that scrolls sideways
        // when a custom scale's longer names ("First", "Third") don't fit.
        return ViewThatFits(in: .horizontal) {
            chipRow(bands, goal)
            ScrollView(.horizontal, showsIndicators: false) { chipRow(bands, goal) }
        }
    }

    private func chipRow(_ bands: [ScaleBand], _ goal: Double?) -> some View {
        HStack(spacing: 6) {
            // Letters are unique in every scale (normalizeScale sees to it),
            // so the letter can be each chip's id.
            ForEach(bands, id: \.letter) { band in
                let on = goal == band.min
                chip(band.letter, on: on) { choose(on ? nil : band.min) }
                    .accessibilityLabel("\(band.letter), \(band.min.formatted()) percent")
            }
            if goal != nil {
                chip("Clear", on: false) { choose(nil) }
            }
        }
    }

    /// One chip: brand-filled when it's the goal, the card color when not,
    /// like the Tasks filter chips. 44 points tall for the finger.
    private func chip(_ text: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.footnote.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(on ? Color.white : Theme.ink)
                .background(on ? Theme.brand(store.profile.accent) : Theme.card, in: Capsule())
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// Save the new goal (nil clears it), then close the chips. A failed
    /// write leaves them open and says so; the class keeps its old goal.
    private func choose(_ next: Double?) {
        if store.setGoal(next, for: course.id) {
            failed = false
            picking = false
        } else {
            failed = true
        }
    }

    /// The sentence under the goal, in the web's words. `@ViewBuilder` lets
    /// each branch return its own Text. A `Text` dropped into another Text's
    /// string keeps its own bold and color, so one sentence can stress a number.
    @ViewBuilder
    private func message(_ goal: Double?, accent: Color) -> some View {
        let used = usedWeight(grades)
        // Rounded to one place, as the web's Math.round(used * 10) / 10.
        let usedText = Text("\(((used * 10).rounded() / 10).formatted())%")
            .bold()
            .foregroundStyle(Theme.dangerInk)

        if let goal {
            if let result = whatIfNeeded(grades, goal) {
                let left = result.remainingWeight.formatted()
                if result.alreadySecured {
                    Text("Already locked in, even a zero on the remaining \(left)% keeps you there. 🎉")
                } else {
                    let needed = Text("\(result.needed.formatted(.number.precision(.fractionLength(1))))%")
                        .bold()
                        .foregroundStyle(accent)
                    let reach = result.outOfReach
                        ? " That's above full marks, only extra credit gets you there." : ""
                    Text("You need \(needed) on the remaining \(left)% of the grade.\(reach)")
                }
            } else if used > 100 {
                // Over 100: whatIfNeeded has nothing to answer, and saying why
                // beats letting the answer quietly disappear.
                Text("Your logged weights add up to \(usedText), more than the 100% a class has. The average still works, it's scaled to fit, but there's no \u{201C}remaining\u{201D} left to work out what you need. Tap a grade to fix its weight.")
            } else if let average = classAverage(grades) {
                // Exactly 100: fully graded, so report the result.
                let finished = average.formatted(.number.precision(.fractionLength(1)))
                if average >= goal {
                    Text("Everything's graded, you finished at \(finished)%. Goal met. 🎉")
                } else {
                    Text("Everything's graded, you finished at \(finished)%, \((goal - average).formatted(.number.precision(.fractionLength(1)))) points short.")
                }
            } else {
                Text("Nothing graded yet.")
            }
        } else if used > 100 {
            // A data problem, not a goal problem, so it shows without a goal too.
            Text("Heads up: your logged weights add up to \(usedText), more than the 100% a class has. Tap a grade to fix its weight.")
        } else {
            Text("Set a target and we'll work out what you still need, and fold it into your projected GPA.")
        }
    }
}
