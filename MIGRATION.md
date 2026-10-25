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

The table records the initial inventory. Checkpoint 2 below records the live
path's replacements; retained legacy comparison code is not yet retired.

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

1. Checkpoint 2 is committed as `8533d24`. Complete the remaining form, picker
   and failure-state manual checks from the behaviour contract.
2. Review and commit checkpoint 3's alternative Core Data repository. It has
   explicit opening, private-queue transactions and save/reopen evidence; it
   does not replace the live in-memory store.
3. Retire legacy VIP/callback source and tests only after mapping equivalent
   replacement requirements. Preserve attribution and historical evidence in Git.
4. Review feature ownership, test grouping, complete concurrency checking and
   real responsiveness iteratively. Require manual acceptance and a final
   feature-by-feature execution/behaviour report before calling migration complete.

At every checkpoint: build, run affected and regression tests, update the contract,
classify differences, and leave a reviewable Git checkpoint. Runtime profiling
and manual regression remain separate from compiler/test success.

## Checkpoint 2 — async live storage and owned task lifetimes

Date: 25 October 2026. Architecture checkpoint committed as `a406aef` before this
work began. This pass follows v0.3's migration and unit-test skills. It covers the
live in-memory path, not the alternative Core Data store or legacy source removal.

### Routes and responsibilities

```text
ListOrdersView → ListOrdersViewModel → OrdersFeature.refresh()
ShowOrderView → ShowOrderViewModel → OrdersFeature's published orders
CreateOrderView → CreateOrderViewModel → OrdersFeature.save(draft)
                                           ↓
                                  OrdersRepository (async)
                                           ↓
                              MemoryOrdersRepository (actor)
```

- `MemoryOrdersRepository` owns the process-only stored collection and atomic
  per-record reads/writes on its own actor, not MainActor. It replaces the live
  callback adapter; it never reads the old static `OrdersMemStore`. Each graph
  gets its own storage. Initial seeds, record order, ID format and placeholder
  total remain the sample's existing behaviour. Nothing is written to disk.
- `OrdersRepository` defines the replaceable async storage boundary. Methods
  return domain values or throw. `Order` and its nested value types now conform
  to `Sendable`; no custom unchecked conformance or detached Task was added.
- `OrdersFeature` owns observable orders, retained errors and request policies
  on MainActor. Repository calls suspend while its actor performs the work.
  Short collection publication/merging remains on MainActor; this is not a
  claim that every model instruction executes on another thread.
- Screen ViewModels retain interaction tasks. The list exposes loading and
  failure presentation; the editor keeps its draft, save progress and alert.
  The App delegate retains the app-lifetime launch task. AppModel keeps only
  its existing feature and one-time launch guard and now awaits refresh.

### Request, ordering and cancellation contract

| Operation | Equivalence/admission | Lifetime and completion |
| --- | --- | --- |
| Feature refresh | All overlapping fetch-all requests share one in-flight task | Every caller awaits that task. Cancelling one caller does not cancel a read needed by others. A pre-cancelled caller does not create a new read. Success/failure publishes before handle cleanup. |
| Feature save | Every admitted command is distinct, including identical-looking new orders | A retained predecessor chain orders the whole operation across awaits. Each caller receives its own result/error. Failure does not strand the next command. Pre-admission cancellation rejects without writing; an admitted commit continues and returns its actual outcome even if its waiter is cancelled. |
| List interaction | Repeated refresh requests share a retained ViewModel task | The screen `.task` awaits its handle; shared refresh may finish after dismissal. |
| Editor interaction | Same draft revision shares its pending task; a changed draft queues behind it | UI disables editing while saving, but programmatic distinct edits are also preserved. Older completion cannot dismiss or replace a newer draft. Already-successful editors do not submit again. Commits survive editor release. |
| Launch opportunity | One AppModel Boolean prevents repeat launch work | Delegate task awaits feature refresh without blocking root UI. Screen requests join the same feature read. |

For this demo, a committed save means the actor's in-memory collection changed,
not disk durability. Process termination still resets the data. No delays,
`Task.yield()`, task groups or background queues were invented for demonstration.
The memory actor's methods do not suspend during their read/modify/write steps.

A delayed initial snapshot now merges records committed since the read began:
it preserves the newer edit **and** unrelated fetched orders. This protects the
existing shared-record requirement rather than dropping the whole older snapshot.

### Approved product change

Matthew Thomas approved showing load failures and a Retry button while retaining
previous orders. The feature retains the error separately; the list ViewModel
provides the message and the View renders it. Initial loading has a small native
progress row. Retry repeats the domain request through the same feature. The
original create/update failure alert and draft retention are preserved.

### Evidence and remaining work

- Final US-region Simulator suite: **128 tests passed**, including all 96 legacy
  tests and 32 tests for the new architecture/async path. Existing empty legacy
  examples still count numerically, not as meaningful coverage.
- Controlled tests cover equivalent refresh completion, cancelled refresh
  waiters, sequential distinct saves, failure cleanup, pre-admission cancellation,
  admitted-save lifetime, stale initial reads, failed loads/retry, editor release,
  duplicate taps and changed drafts. New concurrency tests use continuations and
  bounded XCTest expectations, not sleeps or scheduler polling.
- Real actor tests cover isolated collections, preserved seeds/fields, generated
  IDs/placeholder totals, record-specific update, missing-ID failure and concurrent
  creates. An assertion in ID generation verifies it ran off the main thread in
  that test; this is not a complete performance profile.
- Final result bundle: `/private/tmp/CleanStore-cfa-async-writeback-20261025.xcresult`.
  Earlier 126-test runs preceded the writeback regression fix; they did not
  establish correct on-screen dismissal.
- A `SWIFT_STRICT_CONCURRENCY=complete` diagnostic build-for-testing succeeded.
  It exposed warnings in retained legacy UIKit routing, static state and tests;
  this is not a warning-free project or Swift 6 adoption. A new binding's
  function-conversion warning was corrected with an explicitly inferred closure.
  Swift language mode remains 5; complete checking was a command-line diagnostic
  override, not a silently changed project setting.
- One fresh diagnostic attempt could not connect to CoreSimulator and reported
  an unavailable iOS runtime while compiling storyboards. A standalone retry
  succeeded; this was not treated as a source-code test failure.
- Simulator smoke check by Codex: iPhone Air/iOS 26.2, UK-style formatting,
  uncommitted checkpoint 2. Opened Amy, edited her name, verified single-tap Save
  returns to updated details, created a synthetic order with one Save, observed
  the £1.00 total in the list, then terminated/relaunched and confirmed only the
  two original seeds remained. No real payment data was used.
- Rendering the injected load-failure/Retry state, full keyboard/picker flows,
  VoiceOver, iPad and physical-device checks remain unverified. The unit tests
  establish failure state and retry behaviour, not rendered accessibility.
- Core Data async conversion, exact error/durability handling, legacy retirement,
  complete-concurrency cleanup, physical-device profiling and full manual
  regression remain outstanding. Do not call the whole migration complete.

### Regression found by Simulator interaction

The first async editor build saved its record but needed a second Save tap to
dismiss. Reassigning an identical text-field snapshot during focus resignation
incremented the draft revision, making its completion look obsolete. Draft
revisions now advance only for different snapshots. `Order.hasSameSnapshot`
uses exact dates without changing the legacy tolerance-based `==` contract.
New tests cover identical writeback during save and a genuinely changed earlier
date; the latter must not be discarded as duplicate. Single-tap edit and create
were then rechecked successfully in the Simulator.

### Updated primitive inventory

| Path | Current status |
| --- | --- |
| Live worker main-queue callbacks | Removed from live composition; native async repository calls replace them. |
| Live static in-memory array | Replaced by one instance-owned storage actor per graph. |
| Feature callback lists and save completions | Replaced by awaitable shared refresh and ordered save tasks. |
| Temporary `LegacyOrdersRepository` | Removed, superseded by `MemoryOrdersRepository`. |
| Legacy VIP scenes/worker/static store and original tests | Retained as comparison evidence, no longer the live route; retirement is a separate checkpoint. |
| Core Data `perform` callbacks, construction/deinit saves | Unchanged alternative store; next storage-specific checkpoint. |
| Empty `OrdersAPI` methods and tests | Still classified as a teaching stub, not functioning networking. |

Next: manually accept this live-path checkpoint, commit it, then address the
alternative Core Data implementation and replacement coverage before retiring
the old callback layer. Keep visual/behaviour acceptance separate from test counts.

## Checkpoint 3 — alternative Core Data async repository

Started from committed checkpoint 2 (`8533d24`). The migration and test skills
guided this bounded storage pass. `CoreDataOrdersRepository` lives under the
Orders feature's Storage folder and conforms to the existing async repository
contract. Single-record fetch and delete preserve additional capabilities of the
original alternative store without adding unused operations to the live contract.
AppModel composition, UI, bundle identifier, schema and live process-only lifetime
are unchanged. The legacy store and its 15 callback tests remain temporarily for
comparison, not as the migrated implementation.

### Execution ownership and completion

- `open(at:modelURL:)` explicitly loads the existing model and opens SQLite.
  Construction does not silently start tasks or save data. Under this project's
  Swift 5 concurrency semantics, the nonisolated async factory executes outside
  MainActor. Model decoding is still synchronous framework work there; it has
  not been profiled. SQLite opening uses the framework's asynchronous store-add
  option, not blocking work hidden inside a detached Task.
- One persistent-store description has one completion callback. A checked
  continuation bridges that opening API; CRUD uses the existing native async
  `context.perform` API instead of wrapping the legacy callback variants.
- The repository actor owns a private-queue context connected directly to the
  persistent-store coordinator. Managed objects and mapping stay on that queue;
  callers receive Sendable Order values. No unchecked annotations were added.
- Each write enqueues one indivisible context block: locate/create, map, save,
  return. Errors roll back pending context changes and propagate. Success means
  `context.save()` completed, not merely that a child context pushed changes to
  a parent. There is no deinit save. Independent callers are not promised source
  launch order; feature-level submission ordering remains OrdersFeature's job.
- Cancellation before admission prevents the write. Once queued, the transaction
  reports its actual outcome; cancellation does not pretend a completed save was
  undone. Opening cannot be interrupted by task cancellation: the factory waits
  for the framework callback before acknowledging it. No retained root Task or
  extra scheduler was needed in this repository.
- Missing IDs return explicit errors. Malformed required fields return an error
  rather than force-unwrapping or inventing values; optional second address lines
  remain optional. Shipping speed now reflects the stored value, explicitly
  approved by Matthew Thomas on 25 October 2026 (DIFF-008).
- The default URL is still Documents/CleanStore.sqlite. Automatic model migration
  and inferred mapping are explicitly disabled, matching the original nil-option
  opening policy. The existing `.xcdatamodeld` was not edited.

### Verification and limits

Final run: **136 tests passed**, including the original 96, checkpoint 2's 32,
and 8 new real SQLite tests. Xcode 26.2, iPhone Air Simulator/iOS 26.2, en/US,
Swift 5 with `SWIFT_STRICT_CONCURRENCY=complete` as a diagnostic override.
Result: `/private/tmp/CleanStore-cfa-coredata-final-20261025.xcresult`.

The new tests cover CRUD persistence visible to separately opened readers while
the writer is still alive, stored shipping speed, exact dates and optional fields,
missing/nil IDs and subsequent successful writes, generated defaults, concurrent
creates, pre-cancelled writes, opening failure followed by another opening attempt,
legacy-schema fixtures and malformed records. Each uses a unique temporary test
directory; no populated developer database is touched. Temporary stores are left
for OS reclamation after Core Data releases its handles.

The first successful 136-test run also emitted ambiguous entity-selection
warnings when several models were open. Insertion now resolves the entity from
its own context rather than the class-wide lookup; the final run has no such
warnings. The intentional bad-path opening test still emits expected Core Data
error diagnostics. No compiler warnings point to either new source file, but
retained legacy source/tests still produce complete-checking warnings: this is
not a warning-free project or Swift 6 completion.

Remaining limits: no physical-device profiling, disk-full/protection-error save
injection, process-kill durability test, or deterministic cancellation-during-save
test. Rollback and post-admission cancellation policy are code-reviewed, not fully
fault-injection-proven. The reopening test uses independent coordinators in one
process, not a fresh process. No new manual UI acceptance is claimed for this
storage-only checkpoint. The earlier UI/accessibility gaps remain open.

Next: commit this checkpoint, then map and retire the unused legacy layers in a
separate pass, moving their remaining storage representations under their feature
owner. Re-run the replacement and regression tests before deleting baseline tests.
