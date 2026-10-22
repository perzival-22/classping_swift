# port/: how ClassPing became an iOS app

The plan, the decisions and the record of the SwiftUI port of the ClassPing web
app (github.com/perzival-22/ClassPing). Moved here from the web repo's untracked
`docs/ios/` folder on 2026-10-22 (D-98) so the work lives in GitHub and can go
on while Kelvin's laptop sleeps.

- `IOS_APP.md`: the rules (section 3 is binding).
- `PROGRESS.md`: live state; the top "Current handoff" is the one that counts.
- `PHASES.md`, `DECISIONS.md`, `WEB-TO-IOS-MAP.md`: the plan, every decision, the map.
- `phase-*.md`: one guide per phase. Through 14a Kelvin typed the code from
  them; from 14b they are change notes and the code is on the phase's branch.
- `tools/`: the laptop check scripts (they run in WSL against the laptop's
  `docs/ios/reference`, which stays on the laptop with the session scratch).
- `samples/`: import files for trying the app.

**How a phase lands now (D-98):** Claude pushes it to its own `ios/...` branch,
never `main`. `.github/workflows/checks.yml` runs the logic and store tests on
Linux and builds the app for iOS on a Mac. Kelvin pulls the branch, puts it on
his phone with `xtool dev`, and merges it with `git merge --ff-only`.
