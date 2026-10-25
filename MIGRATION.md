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

The baseline targets iOS 15 and Swift language mode 5. Matthew Thomas subsequently
approved replacing the screens with SwiftUI and raising the minimum to iOS 17,
while preserving the design and workflows. See checkpoint 1 below.

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

## Checkpoint 1 — SwiftUI and feature ownership

Date: 25 October 2026. Implemented; awaiting Matthew Thomas's manual acceptance
and Git checkpoint. **This is not a completed concurrency migration.**

### Approved scope and implementation

- SwiftUI and iOS 17+ were explicitly approved. The three existing workflows now
  use `ListOrdersView`, `ShowOrderView` and `CreateOrderView`, each with its own
  adjacent, main-actor `@Observable` ViewModel. The structural root only hosts
  navigation. No themes, tabs or new product features were added.
- `AppModel` composes a concrete `OrdersFeature`. ViewModels access only that
  feature; they do not reach into workers or storage. Launch requests an early
  refresh, but direct feature requests also work without a launch prerequisite.
- The single-window navigation handoff selects a record in the feature. Details
  capture its ID, and an editor takes its own value draft, so later selections
  cannot retarget an existing screen or mutate a draft accidentally. Multiple
  windows remain unsupported, matching the original product scope.
- Concurrent refresh requests coalesce. Distinct saves are queued in submission
  order, publication follows successful completion, and an older refresh cannot
  overwrite a newly published save. Saving survives release of the editor.
- The original worker and stores remain behind `LegacyOrdersRepository`. This
  deliberately temporary callback boundary keeps architecture work separate
  from async/storage conversion. The live store is still process-only memory,
  including its legacy static state. Core Data schema and location are unchanged.
- Original UIKit scenes, storyboard and tests remain as comparison evidence.
  They are no longer the app's navigation root. Shared domain types are still in
  their legacy folder until the legacy adapters are retired in a later pass.
- Swift language mode remains 5 at this checkpoint. `IsolatedDefaultValues`
  enables actor-isolated default feature dependencies; it is not a claim of
  complete concurrency checking or Swift 6 adoption.

### Verification and limits

- App and both test targets build successfully on Xcode 26.2.
- Full unit run with `-testLanguage en -testRegion US`: **115 tests passed**,
  comprising 96 legacy tests and 19 new tests. Existing assertion-free examples
  remain included in that count; they are not new coverage.
- New tests cover isolated composition, refresh coalescing, ordered commands,
  stale reads, successful/failed saves, retry, editor lifetime, draft isolation,
  selected-order identity, picker presentation and text-focus order.
- The 19 new tests also pass separately with `-testLanguage en -testRegion GB`,
  without the legacy tests' hardcoded US formatting expectations. Result bundle:
  `/private/tmp/CleanStore-cfa-new-tests-GB-20261025.xcresult`.
- Simulator interaction, iPhone Air/iOS 26.2, inherited UK-style formatting:
  opened both seeded orders; edited Amy to Amelia and saved back to details;
  returned to list; created a synthetic Demo order; confirmed generated ID and
  the original £1.00 placeholder total. No real payment data was entered.
- The baseline list was captured before replacement. This limited smoke check
  does not establish full visual parity. Shipping now uses a native SwiftUI menu,
  and the date/time wheel expands in the form rather than becoming a keyboard
  input view. These presentation adaptations need manual acceptance.
- Keyboard traversal, all address/payment fields, picker reopening, cancellation,
  iPad, rotation, Dynamic Type, VoiceOver and physical devices still need manual
  regression. UI tests remain disabled in the inherited shared scheme.
- Build artifacts: `/private/tmp/CleanStore-cfa-architecture`.
- Result bundle: `/private/tmp/CleanStore-cfa-architecture-final-20261025.xcresult`.

The original “Same as shipping address” switch is on by default but has no action
or outlet. Its lack of address-copying behaviour is preserved and recorded as an
exposed defect, not silently corrected. Failure-to-load presentation also remains
the original empty-list behaviour until an explicit product decision.

## Next checkpoints

1. Manually review the SwiftUI architecture checkpoint, especially the form and
   native picker adaptations, and commit it independently of concurrency changes.
2. Convert model operations to useful
   async APIs with explicit execution ownership, command order and error outcomes.
   Replace static live state with isolated instance-owned memory; preserve its
   process-only lifetime and test Core Data compatibility separately.
3. Adopt presentation concurrency over those async features. Retain tasks at
   their real owners and test overlapping calls; Observation is already in place.
4. Review feature ownership, test grouping, complete concurrency checking and
   real responsiveness iteratively. Require manual acceptance and a final
   feature-by-feature execution/behaviour report before calling migration complete.

At every checkpoint: build, run affected and regression tests, update the contract,
classify differences, and leave a reviewable Git checkpoint. Runtime profiling
and manual regression remain separate from compiler/test success.
