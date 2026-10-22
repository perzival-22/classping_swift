# NativeX and the ClassPing iOS handoff

Reviewed locally on October 19, 2026. This analysis distinguishes the artifact's
historical process descriptions from Kelvin's current request to continue to
Phase 9.

## What NativeX Gold contains

NativeX Gold is a benchmark and extraction workflow built from one real port.
It is not yet a general web-to-native compiler or evidence of generalization
across apps.

The extraction path is:

1. Read the web-to-iOS map, phase guides, decisions, current web code and Swift
   reference.
2. Emit per-file classifications: Port, Rebuild, Replace, Connect or Skip.
3. Match named TypeScript and Swift functions, connect test files, and compare
   delivered code blocks with recorded Swift commits.
4. Extract design/navigation representations and build the HTML explorer.
5. Grade an overlaid Swift candidate with a real iOS compile plus Linux logic
   and persistence tests.

At intake the data contained 190 modules, 111 function pairs, 30 test-twin rows,
46 decisions, 105 correction records and 17 phases. Every JSONL file parsed
and had unique record ids. Those were snapshot counts, not claims of exhaustive
semantic pairing or executed coverage.

The most useful learning signal is the distinction between translating pure
logic, rebuilding screens and replacing browser mechanisms with platform
behavior. Notification scheduling and local save/recovery behavior are
particularly valuable examples. Decisions and human corrections explain why a
mechanical line-by-line translation would have been insufficient.

## Evidence and limits

- Training ends at 6b; later reference phases are evaluation data. A translator
  must not retrieve evaluation Swift answers as examples during its evaluation.
- `bucket_split` is a separate path-hash partition for module classification,
  not the temporal translation split.
- Pairing is name-based and constrained by parser heuristics. Split/merged
  functions and screens are not comprehensively paired.
- `tested` checks name mentions in source, not runtime coverage. Test-twin
  records describe file relationships; they do not prove all web cases were
  ported. The GPA twin is explicitly partial in 9a.
- Temporal tags come from first appearance, while bodies come from the current
  reference. Freeze reference, tests, docs and source revisions before claiming
  a reproducible, uncontaminated benchmark result.
- A commit's timing cannot prove whether the work was typed, pasted or carefully
  reviewed. The old 8d “likely pasted” inference was removed.
- A weighted score can conceal regressions. The updated harness additionally
  requires a successful build, exact expected totals, no compile/test failures,
  and a successful process exit. Its self-test must reject the planted bug.
- The tests execute Swift locally. Disposable files and isolated Documents
  paths protect the normal planner during these trusted tests; they are not an
  OS sandbox for arbitrary generated code.

## Actual continuation point

The progress file's morning status was stale. Kelvin's project was clean at
`a66d453`, following `2f5e384` (8d). The note source matched the 8d reference;
four app/store source files held the later notification fix.

Fresh checks of Kelvin's unchanged tree passed 293 logic tests, 58 store tests
and the iOS build without warnings. Kelvin then confirmed that the 8c keyboard/
selection problem and notifications had been fixed on his phone and asked to
move to Phase 9.

The reference now preserves that baseline and adds **9a: Grades and GPA**.
The new guide has seven exact source blocks. Overlaid on Kelvin's current
tree they are identical to the reference and build without warnings.
The updated reference passed 316 logic tests and 57 reference store tests;
Kelvin's own store suites plus the new grade suite passed 69 tests against it.

**9a is delivered, not typed or device-verified.** Its corpus phase has no
invented commit. 9b (custom scales, goals, what-if) and 9c (finals, CSV) remain
planned. The full Phase 9 is not complete.

## Next action

Type [phase-09a-grades-and-gpa.md](phase-09a-grades-and-gpa.md), copy its tests,
add Store+Grades to the store-test source list and run the guide's checks.
Review the typed tree and device behavior before preparing 9b.

No changes were made to Kelvin's WSL project, web application runtime, hosted
services or device installation. Existing unrelated web edits were preserved.
