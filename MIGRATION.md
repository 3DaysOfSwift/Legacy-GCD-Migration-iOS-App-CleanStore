# CleanStore migration ledger

## Scope and provenance

This demonstration adopts Cooperative Feature Architecture and Swift Concurrency
in CleanStore, preserving its product behaviour through reviewable checkpoints.
The original Clean Swift authorship and licence remain intact.

- Upstream: `Clean-Swift/CleanStore`.
- Fork: `3DaysOfSwift/Legacy-GCD-Migration-iOS-App-CleanStore`.
- Branch: `migration/cfa-swift-concurrency`.
- Baseline commit: `e13b868bda3ad1a5987aadbff249b557c1e82d27`.
- Instructions: local **CFA AI Toolkit for iOS**, manifest version **0.3.0**,
  `skills/swift-concurrency-migration/SKILL.md` and its required references.
- Toolkit HEAD: `5d289e7ef64e4528b4b48d1df7f9dc661f53746c`, with existing local
  edits to instructions. This records the working v0.3 toolkit, not an assertion
  that the instructions are an untouched release tag. Those edits are not part
  of this application's migration and have not been modified here.

## Checkpoint 0 — establish the baseline

Date: 25 October 2026. Production source, project settings and tests are unchanged.

The app uses UIKit, storyboards and Clean Swift VIP scenes. Its three screens
list orders, show a selected order, and create/edit an order. Both mutating and
listing interactors use `OrdersMemStore`; its static array shares data across
instances within one process. Core Data is a separate, tested alternative, not
the live store. `OrdersAPI` has empty methods; it is not a functioning server API.

The project targets iOS 15 and Swift language mode 5. The migration's screen
framework and deployment floor require a decision: retain UIKit/iOS 15, or use
SwiftUI with iOS 17+ Observation while preserving the current workflows/design.
The question has been presented to Matthew Thomas; neither has been changed.

### Verification

- Xcode 26.2, build 17C52; iOS Simulator SDK 26.2.
- Unmodified app, unit tests and UI-test target: **build-for-testing passed**.
- Isolated Simulator: `CleanStore Migration Baseline`, iPhone Air, iOS 26.2,
  UUID `86C811B5-3474-437C-A309-6D65671A0357`.
- Baseline unit test execution: **96 tests, 92 passed, 4 failed** with inherited
  region settings. Failures were US-specific formatting expectations receiving
  `29/06/2007` instead of `6/29/07`, and `£1.11` instead of `$1.11`.
- Controlled rerun of the identical binaries with `-testLanguage en -testRegion US`:
  **96 tests passed, zero failures**. No application or test source was changed.
  This establishes a locale-qualified baseline, not region-independent test quality.
- The shared scheme disables UI tests. Compiling their target does not mean they ran.
- Existing `OrdersAPITests` contains 15 empty tests; `CleanStoreTests` also contains
  empty functional/performance examples. Passing these would not establish coverage.
- Manual baseline journeys, iPad, rotation and real-device checks: not yet verified.
- Build artifacts: `/private/tmp/CleanStore-migration-baseline`.
- Result bundle: `/private/tmp/CleanStore-baseline-20261025.xcresult`.
- US-region result bundle: `/private/tmp/CleanStore-baseline-US-20261025.xcresult`.

Reproduce the baseline using a separate test Simulator selected in Xcode, or:

```zsh
xcodebuild -project CleanStore.xcodeproj -scheme CleanStore \
  -destination 'platform=iOS Simulator,name=CleanStore Migration Baseline' \
  -derivedDataPath /private/tmp/CleanStore-migration-baseline \
  -parallel-testing-enabled NO -testLanguage en -testRegion US \
  CODE_SIGNING_ALLOWED=NO test
```

### Exposed concerns, not silent product changes

1. `OrdersWorker` converts a fetch error into an empty successful-looking array.
   An explicit load-failure/retry presentation would be a visible improvement,
   requiring a recorded decision and new tests.
2. Core Data updates do not invoke their completion when an ID is absent. Do not
   wrap these paths in continuations: they would leave an awaiting caller suspended.
3. Core Data saves the private child context per mutation, but saves the parent
   context only during deinitialization. Successful callbacks do not prove disk
   durability. Construction opens SQLite synchronously; deinitialization may trap.
4. `Order` and payment-date equality use a one-sided time difference, so older
   dates can compare equal regardless of distance. This weakens equality-based tests.
5. Date/currency tests assume US strings, although production uses current locale.
   The four baseline failures and the all-green US rerun confirm this mismatch.
   Failed tests: CreateOrderPresenter's expiration-date Spy and Mock tests,
   ListOrdersPresenter's fetched-order formatting test, and ShowOrderPresenter's
   detail formatting test. Replacement tests should explicitly cover locale
   expectations, without changing the app to force US formatting.
6. New orders receive a placeholder total of one when total is NaN. There is no
   pricing/catalogue/payment-processing feature to invent during migration.
7. The sample includes card numbers and CVV fields, including Core Data mappings.
   Treat it as demo data, not a production payment solution; use no real card data.

## Concurrency inventory

All replacements below are planned, not implemented or validated.

| Legacy boundary | Current guarantee and risk | Intended ownership/replacement | Required evidence |
| --- | --- | --- | --- |
| `OrdersWorker` main-queue callbacks | UI delivery is asynchronous on main; failures become empty/nil; no cancellation | Main-actor presentation coordination awaiting an Orders Feature result, with explicit error policy | Success/error delivery, visible outcomes, no early completion |
| `OrdersMemStore` callbacks/static array | Immediate mutations and array order; shared mutable global state has no synchronization | Isolated instance-owned order storage behind the concrete Feature; preserve process-only lifetime | Shared screens see updates; separate test graphs do not share data; create/update ordering |
| `OrdersCoreDataStore` context `perform` | Core Data queue confinement; optional/error, result and throwing-closure API variants | Native async context operations with values crossing the boundary, no managed-object leakage | CRUD parity, missing IDs, exactly one outcome, read-after-write and reopen durability |
| Core Data construction/deinit | Synchronous SQLite opening and parent save tied to object destruction | Explicit opening/saving owned by storage; UI does not wait to exist | Failure/retry, no data loss, schema/store-path compatibility |
| `OrdersAPI` callbacks | Empty implementations never complete; no actual network contract | Keep classified as a stub pending scope decision, not a fabricated async API | No assertion-free tests counted as network evidence |
| Worker test `asyncAfter(1s)` | Simulated latency with 1.1-second timeout; wall-clock scheduling sensitivity | Controllable suspension in replacement tests | Assertions before and after completion; failure and repeated-call tests |
| Navigation delegates/segues | Presentation selects and passes the correct order; no background operation | Screen-specific presentation ownership; stable destination identity | Edit correct order, back without saving, updated details/list |

No production task groups, barriers, semaphores, OperationQueues or timers were
found in the initial source inventory. Do not invent parallel work for appearance.

## Next checkpoints

1. Resolve the screen-framework/deployment decision, document a manual baseline,
   and strengthen missing behaviour protection without changing product behaviour.
2. Establish one coherent Orders Feature and AppModel composition; give each
   screen its own ViewModel. Move business rules out of presentation. Preserve
   the live in-memory lifetime and alternative Core Data compatibility.
3. Commit the architecture checkpoint, then convert model operations to useful
   async APIs with explicit execution ownership, command order and error outcomes.
4. Adopt presentation concurrency/Observation as appropriate to the approved
   platform scope. Retain tasks at their real owners and test overlapping calls.
5. Review feature ownership, test grouping, complete concurrency checking and
   real responsiveness iteratively. Require manual acceptance and a final
   feature-by-feature execution/behaviour report before calling migration complete.

At every checkpoint: build, run affected and regression tests, update the contract,
classify differences, and leave a reviewable Git checkpoint. Runtime profiling
and manual regression remain separate from compiler/test success.
