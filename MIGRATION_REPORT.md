# CleanStore migration implementation report

## Review outcome

Checkpoint 6, 25 October 2026, reviewing committed implementation `0d269e9`.
The architecture and concurrency conversion are implemented; this review found
no blocking structural issue requiring another source rewrite. **Product acceptance
is still open.** This report does not equate passing tests with visual parity,
measured performance improvement, or production readiness.

The migration follows the repository's pinned CFA AI Toolkit v0.3 guidance.
[MIGRATION.md](MIGRATION.md) records the checkpoints and toolkit provenance;
[MIGRATION_BEHAVIOUR_CONTRACT.md](MIGRATION_BEHAVIOUR_CONTRACT.md) maps the original
requirements to replacement tests and approved differences. The original authorship,
licence, Git history and bundle identifiers remain intact.

## Architecture and ownership

```text
SwiftUI screen
    ↓ its own observable ViewModel
AppModel.shared.ordersFeature
    ↓ concrete OrdersFeature API
OrdersRepository contract
    ├── MemoryOrdersRepository actor — live demo
    └── CoreDataOrdersRepository actor — optional, tested alternative
            ↓ private managed-object context
          existing SQLite schema
```

AppModel composes one shared Orders feature; it is not a forwarding service layer.
The three feature-connected screens each own their bespoke ViewModel. They do not
store Task handles or call repositories. RootView is only structural navigation,
so it does not need an empty ViewModel. ViewModels accept an isolated concrete
feature for tests; production screens use their inline, zero-argument ViewModel.

Order values, the storage contract, both repositories and the Core Data schema
belong under `2 - AppModel/Features/Orders`. Formatting lives in `1 - View`.
Tests are grouped into AppModel, Orders feature, Orders persistence, individual
ViewModel files and test support. No production fake, generic service locator,
extra feature actor or new dependency framework was introduced.

## What each operation now guarantees

| Operation | Behaviour and execution ownership | Evidence / boundary |
| --- | --- | --- |
| Launch | AppDelegate retains a refresh Task. AppModel requests one opportunistic load; screens observe the feature rather than waiting for a launch-ready flag. Construction performs no I/O. | AppModel tests cover one launch request and isolated graphs. A failed load remains retryable. |
| List and refresh | Equivalent reads share completion. Failure retains prior orders and exposes an error. A late read cannot overwrite saves committed after it began. | Feature and list tests control suspension and failure order; list rendering was exercised in Simulator. The rendered error/Retry state still needs acceptance. |
| Detail selection | An open detail screen keeps its captured order identity and reads the latest committed value. | Detail tests and manual create/edit navigation. Selection handoffs deliberately retain single-window semantics. |
| Create and edit | Drafts are separate from committed state. Identical pending submissions join; distinct drafts queue. Only the current submitted draft can complete the editor. A failed save retains the draft for retry. | Editor tests cover complete fields, duplicate submission, newer drafts, failure/retry and screen release. Manual single-tap create/edit and reopening passed. |
| Accepted saves | Feature saves await their predecessor, publish only successful results, and allow later work after a failure. Cancellation before feature admission rejects a save; accepted saves finish independently of the screen. | Controlled tests cover cancellation before admission, during a write and while queued. This is not survival across process termination. |
| Live memory storage | CRUD runs on a non-main actor. The two demo seeds and process-only lifetime remain; creating an order still generates its ID and placeholder total. | Seven real memory-repository tests; Simulator create and earlier relaunch checks. No durable live storage was added. |
| Optional Core Data | Opening is explicit and awaited. Managed-object fetch/mapping and each complete change/save/rollback transaction run on the private context queue. Only values leave the storage boundary. | Eight real-storage tests cover CRUD, separate-reader visibility, existing-schema fixtures, malformed data, opening failure/retry and pre-cancelled writes. Not a process-kill or disk-full test. |
| Stored shipping speed | Core Data returns the speed actually stored, not always Standard. | Approved defect correction; real SQLite tests exercise One-Day and Two-Day. The live app remains memory-backed. |

## Main Actor and cooperative execution

UI-observed state, draft/navigation coordination, short collection updates and
locale-sensitive presentation formatting stay on the Main Actor. Storage work
has its own non-main owner. Async calls suspend while awaiting results; no blocking
waits, semaphores, application GCD scheduling, OperationQueues, detached Tasks or
Combine observation remain in the production Swift source.

The retained framework boundary is deliberate: Core Data still owns its private
queue, and `loadPersistentStores` uses one checked continuation for its one store
description. Framework opening cannot be interrupted by cancelling the caller;
the factory awaits the outcome before checking cancellation again. An actor is
not a dedicated thread or a reserved CPU core. No Task.yield is needed to make
these small operations appear cooperative.

Complete concurrency checking is enabled in Debug and Release. Swift language
mode remains **5**, not Swift 6. The two-row demo does not establish large-dataset
performance: row formatting creates formatters, lookup is linear, and refresh
merging runs on Main Actor with expected linear work. Profile representative data
before adding caches or more executor boundaries. No speed, memory or IPA-size
improvement is claimed without measurements.

## Automated and build evidence

- Checkpoint 6 regression runs: **54 tests passed in en/US and all 54 passed
  again in en/GB**, zero failures in either run.
- Test distribution: 2 AppModel, 15 feature, 7 memory storage, 8 Core Data,
  6 list ViewModel, 3 detail ViewModel and 13 editor ViewModel tests.
- Unsigned generic-iOS **Release build passed**. Built metadata confirms iOS 17.0,
  existing `com.clean-swift.CleanStore`, iPhone/iPad support, retained orientations
  and disabled multiple-scene support. This is a device-SDK compilation, not a
  signed archive, App Store validation or physical-device execution.
- Both test result bundles and the device-build bundle report no compiler issue summaries.
  Core Data invalid-path tests intentionally emit framework error logs; Xcode's
  no-AppIntents-dependency extraction message is not an app concurrency warning.
- The inherited UI-test placeholder remains skipped. No automated UI tests ran.

Evidence (temporary local artifacts, not committed):

```text
/private/tmp/CleanStore-cfa-checkpoint6-US.xcresult
/private/tmp/CleanStore-cfa-checkpoint6-GB.xcresult
/private/tmp/CleanStore-cfa-checkpoint6-device-Release.xcresult
```

The baseline's 96 US-qualified tests included repeated callback/spy variants and
18 empty or unrelated examples. The replacement's 54 tests must be assessed by
the requirement mapping, not described as identical coverage merely because they
pass. Historical baseline and checkpoint results remain in the ledger.

## Manual Simulator evidence

Codex exercised committed `0d269e9` on the isolated iPhone Air/iOS 26.2 Simulator
on 25 October 2026, with UK-style date/currency output and synthetic data only:

- Created a third order with all 16 text fields populated; a single Save returned
  to the list with a generated ID and £1.00 total.
- Opened its correct five detail values, then reopened the editor and inspected
  every stored text field. One-Day shipping remained selected.
- Changed billing ZIP from 10001 to 10002, saved once, returned to the same order
  ID/date/total, and reopened to confirm 10002.
- Exercised hardware Return progression through contact/address fields and the
  lower CVV/billing sequence. Some rapid batched input did not produce the exact
  intended text, so this is **not** a complete keyboard-quality pass. The actual
  field values visible before saving were the ones verified after reopening.

Checkpoint 4 separately records both seeded details, Two-Day shipping and changed
expiry selection, Back discarding a draft, and relaunch restoring the two seeds.
These are manual smoke checks, not screenshot-diff proof of baseline visual parity.

## Preserved limitations and future work

- The legacy one-sided date equality remains (DIFF-003). Draft-change detection
  and replacement assertions use exact snapshots so that it cannot hide date edits.
- “Same as shipping address” remains visually present but does not copy fields
  (DIFF-006). Changing that behaviour requires a separate product decision.
- Generated random IDs and optional/duplicate legacy IDs have not been redesigned.
  Tests show merge behaviour does not trap; they do not guarantee unique SwiftUI
  row identity for malformed records.
- This remains a demonstration, not a payment product. Never enter real card/CVV
  data. No payment processing, pricing engine or network service was invented.
- Empty inherited AppDelegate lifecycle callbacks are harmless cleanup candidates,
  not a concurrency defect or a reason to prolong the migration.

## Acceptance remaining before closure

Matthew Thomas should accept the SwiftUI shipping-menu/inline-date-wheel adaptation
and manually check software-keyboard traversal/dismissal, scrolling, VoiceOver,
Dynamic Type, iPad/rotation and a physical device. The rendered load-error/Retry
and save-error/retry journeys also need verification with controlled failures;
their feature/ViewModel state transitions are tested, but the live memory demo
does not naturally provide those failures. No fault-injection controls were added
to production just for this report.

Real-device Instruments profiling, large datasets, disk-full/protection failures,
rollback after a real SQLite save failure and cancellation during a real admitted
SQLite transaction remain explicit follow-up work, not passed checks. Agree which
are requirements for this demonstration and which are deferred. Then record the
acceptance decision and close the migration; do not silently mark these gaps green.
