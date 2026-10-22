---
title: "Phase 9b+ fix: the finals card's Clear"
date: 2026-10-20
---

# Phase 9b+ fix: the finals card's Clear

One file, after your 9b+ phone check (commit `b08680f`, identical to the 9b+
reference). You reported that after Clear and a full close, the card comes
back with a date: first the previous date (9c), then today (9b+).

**What I found (D-60).** I read the app's save file off your phone over USB,
read-only. [Certain] After your last test it was written at 15:57:51 with the
finals date set to today, 2026-10-20. [Certain] Clear itself saves correctly:
the store test clears a date, reloads the file, and gets no date. Only the
Save button writes a date, and after Clear the card left an open picker with
a date already in it, right above Save:

- in 9c the picker still held the date you'd just cleared, so a Save put it
  straight back: "it shows the previous set date";
- in 9b+ D-58 reset the picker to today, so a Save set finals to today: "it
  takes the current day as the finals day".

[Likely] Save got tapped after Clear, the way you'd confirm a change. That
trap is the bug either way, so the card no longer offers it: after Clear (and
whenever there's no date) it shows the web's sentence and one button, **Set
finals date**. The picker and Save appear only after you tap it, and Cancel
is always there. If you're sure you never tapped Save, tell me, because then
something else is writing the date and this won't be the whole fix.

**Verification (2026-10-20):** the reference iOS build passed with no
warnings. No logic or store file changed (371 logic and 67 reference store
tests stand). The guide's block laid over your b08680f tree is identical to
the reference, and that tree built with no warnings. Not yet checked on the
phone.

## 1. Goal

Clear means cleared, and stays cleared after a full close.

**On your phone:** Grades → Days to Finals → Edit → **Clear**. The card says
"Add your finals date to see a live countdown." with a **Set finals date**
button and no picker. Close the app fully and reopen: same card.

## 2. New Swift concepts

None. The card's `if` / `else` grows from two branches to three.

## 3. What it maps from the web

`components/FinalsCountdown.tsx` shows the date field and Save as soon as
there's no date. The phone waits for **Set finals date** (D-60): one more tap
the first time, in exchange for a Clear that can't be undone by the next tap.
D-58's picker reset is gone with it: the picker now opens on today whenever
there's no date.

## 4. Files, in the order to type them

### 4.1 `~/ClassPing/Sources/ClassPing/Screens/Grades/FinalsCountdown.swift` (replaces your 9b+ file)

Changed spots:

- **Header** (changed).
- **`body`** (changed): `if editing { editor } else if hasDate { countdown }
  else { empty }`. Before, an empty card always showed the editor.
- **`empty`** (new): the sentence and the **Set finals date** button.
- **`editor`** (changed): a different first line when there's no date yet,
  and **Cancel** always shown (Clear still only with a date).
- **`clear()`** (changed): back to closing the picker; D-58's `draft = .now`
  is gone, because the picker isn't on screen after Clear any more.

```swift
//
//  File:    ~/ClassPing/Sources/ClassPing/Screens/Grades/FinalsCountdown.swift
//  Phase:   9c (finals countdown and the CSV report), changed in 9b+ (D-58)
//           and again after its phone check (D-60)
//  Ports:   components/FinalsCountdown.tsx
//
//  Summary: The Days to Finals card on Grades: a live count of the days left
//           until your finals date, and a small form to set, change or clear
//           it. The date is saved on your profile, as on the web. Since D-60
//           the picker and Save only appear after you ask for them, so Clear
//           can't be followed by a Save of a date you never picked.
//

import SwiftUI

struct FinalsCountdown: View {
    @Environment(Store.self) private var store

    /// True while the picker is open: setting a first date, or changing one.
    @State private var editing = false
    /// The day in the picker, before you tap Save.
    @State private var draft = Date.now
    /// True when the last Save or Clear couldn't be written to the phone.
    @State private var failed = false

    var body: some View {
        let accent = store.profile.accent
        let saved = store.profile.finalsDate
        // A saved date that isn't a real day counts as none, so the card asks again.
        let hasDate = isValidDate(saved)

        VStack(alignment: .leading, spacing: 12) {
            // The label, with Edit beside it while the countdown shows.
            HStack {
                Text("DAYS TO FINALS")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if hasDate && !editing {
                    Button("Edit") { openEditor(saved) }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.brandDeep(accent))
                        .frame(minHeight: 44)
                        .accessibilityLabel("Edit finals date")
                }
            }

            // CHANGED after the 9b+ phone check (D-60): three states, not two.
            // The picker is open only while `editing`; with no date and no
            // picker, the card just offers to set one.
            if editing {
                editor(hasDate: hasDate)
            } else if hasDate {
                // TimelineView (5a) redraws once a minute, so the count turns
                // over at midnight even if this screen stays open.
                TimelineView(.everyMinute) { context in
                    if let status = finalsStatus(saved, context.date) {
                        countdown(status, accent)
                    }
                }
            } else {
                empty
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    /// The big number (or Today, or Done) and the sentence under it.
    private func countdown(_ status: FinalsStatus, _ accent: Profile.Accent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(status.headline)
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.brandDeep(accent))
                if let unit = status.unit {
                    Text(unit)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
            }
            Text(status.message)
                .font(.footnote)
                .foregroundStyle(Theme.muted)
        }
        // One VoiceOver stop: "51, days, Finals begin Thursday, Dec 10. …"
        .accessibilityElement(children: .combine)
    }

    // NEW after the 9b+ phone check (D-60)
    /// No date yet, or just cleared: the web's prompt, with a button instead
    /// of an open picker. Nothing here can save a date by itself.
    private var empty: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add your finals date to see a live countdown.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)
            Button("Set finals date") { openEditor(nil) }
                .buttonStyle(.borderedProminent)
        }
    }

    /// The picker, to set a first date or change the one you have.
    /// CHANGED (D-60): Cancel is always there, so opening the picker by
    /// mistake costs nothing. Clear only when there's a date to clear.
    private func editor(hasDate: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(hasDate ? "Update your finals date." : "Pick the first day of your finals.")
                .font(.footnote)
                .foregroundStyle(Theme.muted)

            // Date only, like the planner's picker in 7b. The compact style
            // shows the day as a button that opens a calendar.
            DatePicker("Finals date", selection: $draft, displayedComponents: .date)

            HStack(spacing: 8) {
                Button("Save", action: save)
                    .buttonStyle(.borderedProminent)
                if hasDate {
                    Button("Clear", action: clear)
                        .buttonStyle(.bordered)
                }
                Button("Cancel") {
                    editing = false
                    failed = false
                }
            }

            // The screen's own banner sits far above this card, so say it here too.
            if failed {
                Text("Couldn't save on this device. Try again.")
                    .font(.footnote)
                    .foregroundStyle(Theme.danger)
            }
        }
    }

    /// Open the picker on the saved day, or on today when there isn't one:
    /// the web's `openEdit`.
    private func openEditor(_ saved: String?) {
        // `deadlineDayStart` turns "2026-12-10" into local midnight that day.
        draft = deadlineDayStart(makeDeadline(saved, nil)) ?? .now
        failed = false
        editing = true
    }

    /// Save the picked day as "yyyy-MM-dd" (`dayOf`: your own calendar day,
    /// never UTC's). The form stays open with a red line if the phone
    /// couldn't write it.
    private func save() {
        failed = !store.setFinalsDate(dayOf(draft))
        if !failed { editing = false }
    }

    /// Remove the date. The picker closes and the card offers to set a new one
    /// (D-60), so the next tap can't re-save a date by accident.
    private func clear() {
        failed = !store.setFinalsDate(nil)
        if !failed { editing = false }
    }
}
```

## 5. Run it

```bash
cd ~/ClassPing
xtool dev build
xtool dev
```

1. **Clear:** Grades → Edit → **Clear**. The card shows the sentence and
   **Set finals date**, no picker, no Save.
2. **Full close:** swipe ClassPing away in the app switcher, reopen, go to
   Grades: still "Add your finals date…".
3. **Set it again:** tap **Set finals date**. The picker opens on today, with
   Save and Cancel. Tap **Cancel**: back to the button, nothing saved. Tap
   **Set finals date**, pick your real date, **Save**: the countdown.
4. **Edit:** Edit shows Save, Clear and Cancel, as before.

Keep the phone plugged in while you do steps 1 and 2 if you can: I can read
the save file again afterwards and confirm the date is really gone.

## 6. Done when

- [ ] After Clear the card shows Set finals date, and that survives a full
      close.
- [ ] Set finals date → Cancel saves nothing; Save sets the countdown.

## 7. If it breaks

- **The picker still shows after Clear:** `body` still says
  `if hasDate && !editing { … } else { editor }`. The editor belongs only to
  the `if editing` branch.
- **Cannot find 'empty' in scope:** the `empty` property goes inside the
  struct, next to `countdown`.
