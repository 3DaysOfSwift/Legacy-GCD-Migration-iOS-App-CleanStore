# CleanStore product behaviour contract

Baseline: `e13b868bda3ad1a5987aadbff249b557c1e82d27`, 25 October 2026.
Paths below are relative to the repository. Legacy test class names refer to
their files at the baseline commit; checkpoint 4 records their retirement.

Confirmed means explicit tests support intent, not that end-to-end behaviour has
been manually verified. Inferred rows are source evidence requiring acceptance.
Checkpoint 1 added SwiftUI replacements; checkpoint 4 removes the unused legacy code.
The baseline table below is retained as provenance. The checkpoint mapping after
it records replacement protection and current results, not completed migration.

| ID | Plain-English requirement | Legacy evidence | Evidence status | Baseline | Replacement protection | Post-migration result | Manual regression | Difference and approval |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BEH-001 | Returning to the order list refreshes its orders. | `ListOrdersViewController.viewWillAppear`; `ListOrdersViewControllerTests.testShouldFetchOrdersWhenViewDidAppear` | Confirmed | US baseline passed | Pending list ViewModel test | Not migrated | Open list, create/edit, return | None |
| BEH-002 | Each list row displays the order's short date and currency-formatted total. | `ListOrdersPresenterTests.testPresentFetchedOrdersShouldFormatFetchedOrdersForDisplay`; `ListOrdersViewControllerTests.testShouldConfigureTableViewCellToDisplayOrder` | Confirmed | Formatting test failed in inherited region; passed in US | Pending presentation tests | Not migrated | Compare rows in US and device locale | Test strings assume US; production uses locale |
| BEH-003 | Selecting a row opens details for that order, showing ID, date, email, full name and total. | `ListOrdersRouter.passDataToShowOrder`; `ShowOrderPresenterTests.testPresentOrderShouldFormatOrderForDisplay`; `ShowOrderViewControllerTests.testDisplayOrderShouldUpdateLabelText` | Inferred | Source and component tests; routing unprotected | Pending route identity and detail tests | Not migrated | Open both seeded rows | None |
| BEH-004 | Creating an order collects contact, billing, payment and shipping fields and returns to the refreshed list on success. | `CreateOrderViewController.saveButtonTapped`; `CreateOrderViewControllerTests.testSuccessfullyCreatedOrderShouldRouteBackToListOrdersScene`; `OrdersMemStoreTests.testCreateOrderShouldCreateNewOrder_InnerClosure` | Confirmed | Component tests passed in US | Pending create Feature/ViewModel tests | Not migrated | Enter synthetic data, save, inspect | None |
| BEH-005 | Editing an order prepopulates its form and updates the same order, retaining its ID, date and total. | `CreateOrderPresenterTests.testPresentOrderToEditShouldFormatTheExistingOrderForDisplayUsingSpy`; `CreateOrderViewController.saveButtonTapped`; `OrdersMemStoreTests.testUpdateOrderShouldUpdateExistingOrder_InnerClosure` | Confirmed | Component tests passed in US | Pending field-preservation and edit tests | Not migrated | Change one field, inspect all others | None |
| BEH-006 | Saving an edit returns to details showing the updated order. | `CreateOrderViewControllerTests.testSuccessfullyUpdatedOrderShouldRouteBackToShowOrderScene`; `CreateOrderRouter.passDataToShowOrder`; `ShowOrderViewController.viewWillAppear` | Confirmed | Routing/data propagation needs integration coverage | Pending edit/detail integration test | Not migrated | Edit, save, inspect details then list | None |
| BEH-007 | The shipping picker offers Standard, One-Day and Two-Day shipping in that order and displays the selected option. | `CreateOrderInteractorTests.testShippingMethodsShouldReturnAllAvailableShippingMethods`; `CreateOrderViewControllerTests.testSelectingShippingMethodInThePickerShouldDisplayTheSelectedShippingMethodToUser` | Confirmed | Passed in US | Pending shipping-value tests | Not migrated | Select each option, save and reopen | None |
| BEH-008 | The expiration-date picker displays a short formatted date and restores the recorded date while editing. | `CreateOrderPresenterTests.testPresentExpirationDateShouldConvertDateToStringUsingSpy`; `CreateOrderViewControllerTests.testShouldDisplayOrderToEdit` | Confirmed | Expiration Spy/Mock failed in inherited region; passed in US | Pending date presentation tests | Not migrated | Select date, edit saved order | None |
| BEH-009 | Return advances focus to the next form field, dismissing the keyboard at the last field; tapping a form row focuses its field. | `CreateOrderViewControllerTests.testCursorFocusShouldMoveToNextTextFieldWhenUserTapsReturnKey`, `testKeyboardShouldBeDismissedWhenUserTapsReturnKeyWhenFocusIsInLastTextField`, `testTextFieldShouldHaveFocusWhenUserTapsOnTableViewRow` | Confirmed | Passed in US | Pending new UI focus protection | Not migrated | Keyboard traversal and scrolling on device | None |
| BEH-010 | Failed creation or update keeps the editor available and presents the corresponding failure alert. | `CreateOrderViewControllerTests.testCreateOrderFailureShouldShowAnAlert`, `testUpdateOrderFailureShouldShowAnAlert` | Confirmed | Tests inject failure; live store succeeds for normal create | Pending save failure/retry tests | Not migrated | Inject failure; verify draft survives retry | None |
| BEH-011 | The live demo starts with Amy and Bob; new/edited orders are shared across screens within the process, not persisted across launches. | `OrdersMemStore.orders`; live store construction in List/Create interactors | Inferred | Source evidence; relaunch unverified | Pending isolated-store and composition tests | Not migrated | Fresh launch, create, terminate/relaunch | Do not silently switch to Core Data |
| BEH-012 | Backing out of an editor without Save does not commit its draft. | Form collection occurs only in `saveButtonTapped`; navigation uses standard Back | Inferred | No focused test identified | Pending discard-draft test | Not migrated | Change field then Back; inspect original | None |
| BEH-013 | The alternative Core Data store supports create, fetch, update and delete while retaining its existing schema and SQLite location. | `OrdersCoreDataStoreTests` CRUD variants; `CleanStore.xcdatamodeld`; `OrdersCoreDataStore.init` | Confirmed | CRUD tests passed; reopen durability unprotected | Pending compatible storage tests | Not migrated | Separate test store; save/reopen inspection | Not the live app store; durability concern in ledger |
| BEH-014 | A new order receives an ID and the sample's placeholder total when no total is supplied. | `OrdersStoreUtilityProtocol.generateOrderID`, `calculateOrderTotal`; editor uses nil ID/NaN total | Inferred | Happy-path tests do not fully establish generation/NaN cases | Pending focused characterisation | Not migrated | Create synthetic order and inspect | Placeholder total is not a pricing engine |

## Differences requiring decisions

| ID | Evidence | Classification | Decision/status |
| --- | --- | --- | --- |
| DIFF-001 | Worker fetch failure becomes `[]`; UI cannot distinguish failed load from empty results. | Intended approved change | Matthew Thomas approved error + Retry with retained orders on 25 October 2026. Implemented/tested in checkpoint 2; rendered failure-state acceptance remains outstanding. |
| DIFF-002 | Core Data update with unknown ID has no callback on the empty-fetch branch. | Existing defect exposed | Checkpoint 3 replacement throws an explicit not-found error; missing/nil update, fetch and delete tests pass. The unused legacy implementation remains until retirement. |
| DIFF-003 | Legacy equality treats sufficiently earlier dates as equal, potentially hiding incorrect test results. | Existing defect exposed | Do not use existing whole-order equality as sole replacement proof; review precise field assertions |
| DIFF-004 | Presenter tests assert US strings but formatters use the current locale. | Environment or flaky evidence | Four tests fail with inherited UK-style output; identical binaries pass all 96 tests in US region. Keep product locale-aware; make replacement tests locale-explicit |
| DIFF-005 | UIKit/iOS 15 → SwiftUI/iOS 17+ changes framework and device support. | Approved scope change | Matthew Thomas approved “Yes—SwiftUI, iOS 17+” on 25 October 2026; implemented in checkpoint 1 |
| DIFF-006 | The original “Same as shipping address” switch has no action or outlet and does not copy the address. | Existing defect exposed | Preserve behaviour for now; address-copying requires a separate decision/test |
| DIFF-007 | Shipping uses a native SwiftUI menu; the date/time wheel expands in the form instead of using a text-field input view. | Framework presentation adaptation | Values and editing workflows retained; manual acceptance pending |
| DIFF-008 | Legacy Core Data mapping reads every shipping speed as Standard despite storing its actual value. | Approved defect correction | Matthew Thomas approved preserving stored shipping speed on 25 October 2026. Checkpoint 3 replacement and real SQLite round-trip tests implement this; legacy mapper remains unchanged for baseline comparison. |

## Checkpoint 1 replacement protection

All 19 new unit tests pass as part of the 115-test US-region run. The table
distinguishes component protection from actual Simulator interaction. Legacy
tests still pass against legacy types, not automatically against replacement UI.

| Requirements | Replacement evidence | Current result and remaining checks |
| --- | --- | --- |
| BEH-001–002 | `ListOrdersViewModelTests`; `OrdersFeatureTests` coalescing/stale-refresh tests; `ListOrdersView.onAppear` | Rows and locale formatting protected; refreshed list observed after save. Automated return-navigation test remains to add. |
| BEH-003 | `ShowOrderViewModelTests` stable identity and shared-state tests | Both Amy and Bob opened with their own IDs in Simulator. |
| BEH-004–006 | `CreateOrderViewModelTests` edit field preservation; feature ordered-save tests; detail observation test | Simulator edited Amy to Amelia and returned to updated details; synthetic new order returned to list. Complete field-by-field manual round trip remains. |
| BEH-007–008 | `CreateOrderViewModelTests.testNewFormStartsBlankWithLegacyPickerDefaults` | Option order, blank initial labels, chosen speed/date protected. Full native picker interaction/reopening still needs manual checks. |
| BEH-009 | `CreateOrderViewModelTests.testTextFocusAdvancesAndEndsAtLastField` | Focus policy protected; actual software keyboard traversal remains manual. Picker rows are native controls rather than text fields. |
| BEH-010 | `CreateOrderViewModelTests.testFailureRetainsDraftAndAllowsRetry` | Failed create retains draft and permits retry. Update alert title follows draft ID; explicit failure injection in UI still outstanding. |
| BEH-011 | `AppModelTests` isolated graphs; unchanged live adapter/store | Both seed records observed. Live static store deliberately remains until concurrency checkpoint; full relaunch acceptance still outstanding. |
| BEH-012 | `CreateOrderViewModelTests.testDraftsAreIndependentAndBackWithoutSavingHasNoSideEffect` | Draft mutation does not publish to feature. UI back/discard still needs manual regression. |
| BEH-013 | Original `OrdersCoreDataStoreTests`, unchanged implementation/schema | Original CRUD tests still pass; async conversion and reopen durability remain outstanding. |
| BEH-014 | Unchanged legacy store; Simulator create journey | New record had generated ID and £1.00 placeholder total; focused store-generation test still outstanding. |

Additional protection covers duplicate Save taps, commits surviving editor
release, distinct saves completing in order, failure allowing queued work to
proceed, and stale reads not reverting a successful edit. No timing sleeps were
introduced in the new tests.

## Checkpoint 2 replacement protection

128 tests passed in the final US-region run. The original 96 remain unchanged;
the new path has 32 tests. Existing APIs are now awaited directly by tests.

| Requirements | New evidence | Status |
| --- | --- | --- |
| BEH-001–002 | List ViewModel awaits a shared refresh; repeated refresh and locale-formatting tests | Passed; SwiftUI initial work uses `.task`. |
| BEH-003, BEH-005–006, BEH-012 | Existing identity, edit and discard tests converted to async; changed drafts queue and do not let an older completion dismiss a newer edit | Passed; full UI manual acceptance remains separate. |
| BEH-004, BEH-010 | Feature ordered-save/failure tests; ViewModel duplicate, retry, released-editor tests | Passed; each command owns its result; no screen-disappearance data loss. |
| BEH-007–009 | Existing picker/focus tests retained; no picker behaviour redesign in this pass | Passed component tests; manual gaps from checkpoint 1 remain. |
| BEH-011 | `MemoryOrdersRepositoryTests.testDemoSeedsAndSeparateInstancesPreserveProcessOnlyLifetime` | Passed; live storage no longer uses a static array. Process-only lifetime preserved. |
| BEH-013 | Original Core Data CRUD suite remains unchanged | Passed baseline tests; native async conversion/reopen durability still pending. |
| BEH-014 | Real repository test for generation, placeholder total and field preservation | Passed, with injected deterministic ID. |
| DIFF-001 | Feature failure-retention/retry test and List ViewModel first-load/refresh failure tests | Approved improvement implemented; previously loaded orders remain visible. |
| BEH-004–006 | `testIdenticalTextFieldWritebackDuringSaveStillCompletesEditor` and `testChangedDateIsNotMistakenForIdenticalWriteback` | Simulator exposed a two-tap-dismissal regression after the initial 126-test pass. Fixed using exact draft snapshot comparison; single-tap edit and create reverified. |

Additional concurrency evidence: pre-admission cancellation writes nothing;
an admitted save completes despite caller cancellation; a cancelled refresh
waiter does not cancel shared work; a delayed initial fetch preserves both newer
edits and unrelated records. Failures release the queue for subsequent work.

## Checkpoint 3 replacement protection

136 tests passed with complete concurrency checking enabled diagnostically.
`CoreDataOrdersRepositoryTests` adds eight real-storage tests; the 15 original
Core Data callback tests are retained. The app still composes MemoryOrdersRepository.

| Requirements | Replacement evidence | Result / qualification |
| --- | --- | --- |
| BEH-013 create/fetch/update/delete | `testCreateUpdateAndDeleteReachDiskBeforeReturning` | Separate readers see committed mutations while writer remains alive; no deinit dependency. Same process, independent coordinators—not a process-kill test. |
| BEH-013 compatibility | `testReadsExistingSchemaRecordsWithoutRewritingThem` | A fixture written with the existing managed-object schema is readable; original Documents/CleanStore.sqlite location asserted. Model file unchanged. |
| BEH-013 explicit failures, DIFF-002 | `testMissingFetchUpdateAndDeleteThrowAndDoNotStrandLaterWrites`, `testMalformedRecordReturnsErrorInsteadOfCrashing` | Missing/nil IDs and malformed fields return errors, not hangs/crashes. Valid later commands still work. |
| BEH-013 opening errors | `testOpeningFailureIsReturnedAndCanBeRetried` | Invalid test path returns an error; subsequent valid opening succeeds. No silent in-memory fallback. |
| BEH-014 defaults | `testGeneratedIDAndTotalPreserveDraftAndRunOffMain` | ID/default total preserved; ID-generation closure observed off-main. Not a performance profile. |
| DIFF-008 stored shipping speed | CRUD round-trip and existing-schema fixture tests | Approved fix verified for saved One-Day/Two-Day values; optional street2 and exact dates also checked. |
| Concurrency isolation | `testConcurrentCreatesKeepBothRecordsInIndependentTransactions`, `testPreCancelledWriteDoesNotMutateStore` | Concurrent records both survive; pre-cancelled command writes nothing. Submission order across independent callers is not promised. |

New tests use isolated temporary databases. Expected Core Data error logs arise
from the intentional invalid-path test. Post-admission cancellation, actual
disk-full/protection failures and rollback after a real failed save remain
fault-injection gaps, not claimed coverage. The existing feature fake tests
still protect UI failure/retry state, separately from these storage guarantees.

## Manual regression record

Checkpoint 2 smoke check: Codex, 25 October 2026, uncommitted async checkpoint,
isolated iPhone Air/iOS 26.2, UK-style date/currency output. Edit/save returned to
updated details on one tap after the writeback fix; new synthetic order returned
to list on one tap with generated ID and £1.00 total. Terminate/relaunch restored
the two demo seeds, confirming process-only lifetime. Rendered failure/Retry UI
and full accessibility/form regression still require acceptance.

Limited checkpoint-1 smoke check performed by Codex on 25 October 2026 against
the uncommitted architecture checkpoint: isolated iPhone Air Simulator, iOS 26.2,
inherited UK-style date/currency output. Both seed details, edit/save/return,
create/save/return and generated ID/total passed. Baseline list screenshot:
`/private/tmp/CleanStore-baseline-list.png`. No full baseline form journey or
complete post-change manual regression has been established.

For each remaining journey above record tester, date, Git commit, OS,
device, locale, outcome and linked defect. Capture baseline screens before their
replacement. Repeat at the architecture checkpoint and after concurrency work;
include navigation, keyboard, draft preservation, repeated Save, error recovery,
iPad/rotation and relaunch behaviour. Use synthetic payment data only.

Do not remove a legacy test merely because its implementation is being removed:
first link the corresponding replacement protection here and demonstrate parity.

## Checkpoint 4 legacy-test retirement map

Before retirement, the combined suite passed **142 tests, zero failures** on
25 October 2026 (Xcode 26.2, iPhone Air/iOS 26.2, en/US, complete concurrency
checking diagnostic override).
Result: `/private/tmp/CleanStore-cfa-retirement-before-20261025.xcresult`.

The following maps every retired test file to replacement protection. Assertions
about calling a VIP spy or configuring a UIKit table are not retained as API
requirements: their observable result is protected below. Native-control rendering
and navigation still require manual acceptance; unit tests do not prove them.

| Retired tests | Requirements and replacement evidence |
| --- | --- |
| ListOrdersInteractorTests, ListOrdersPresenterTests, ListOrdersViewControllerTests | BEH-001–002: ListOrdersViewModelTests covers refresh, row count/content and current-locale formatting; OrdersFeatureTests covers shared loads, failure retention and stale refresh. Single-list composition is visible in ListOrdersView; UIKit section/reload mechanics no longer exist. |
| ShowOrderInteractorTests, ShowOrderPresenterTests, ShowOrderViewControllerTests | BEH-003, 006: ShowOrderViewModelTests covers stable selected identity, all five displayed values, and updates observed after an edit. SwiftUI binds those values directly. |
| CreateOrderInteractorTests, CreateOrderPresenterTests | BEH-004–008: CreateOrderViewModelTests covers blank defaults, every prepopulated field, three shipping choices, current-locale expiry formatting, unchanged identity/date/total, create/update completion and precise draft snapshots. Duplicate Spy/Mock variants become one outcome check. |
| CreateOrderViewControllerTests | BEH-004–010, 012: CreateOrderViewModelTests covers create/edit completion, both failure titles with retained drafts and retry, all 16 text-field focus transitions, final nil focus, picker values and discard. The View binds didSave to dismissal, error state to an alert and focus to FocusState. Actual keyboard, menu, wheel and navigation rendering remain manual checks, not automated UI coverage. |
| OrdersWorkerTests | BEH-004–006, 011: OrdersFeatureTests awaits fetch/create/update and proves ordered saves, failure release and cancellation policy; List/Create/Show ViewModel tests cover results reaching UI state. |
| OrdersMemStoreTests | BEH-011, 014 and concrete storage CRUD: MemoryOrdersRepositoryTests covers all-record/single-record fetch, create, update, delete, missing IDs, generated defaults, field preservation and separate-instance lifetime. Three callback-signature variants are replaced by one async interface. |
| OrdersCoreDataStoreTests | BEH-013–014, DIFF-002/008: CoreDataOrdersRepositoryTests covers all five CRUD operations, reopen visibility, schema fixture compatibility, errors, later recovery and stored shipping speed. Three callback-signature variants become native async operations. |
| OrdersAPITests | Fifteen empty test bodies against an unused API stub; no verified network behaviour existed to transfer. No networking feature is introduced. |
| CleanStoreTests | Empty example and empty performance measurement; neither provides a product requirement or useful benchmark. |
| TheLittleMocker | Unrelated mock-authentication teaching example, not a CleanStore feature or authentication requirement. |

Checkpoint 4 adds six tests before deletion: two memory fetch/delete tests, three
editor tests (complete prepopulation/pickers, failed-update retry and permissive
blank saves), and one detail-display test. It also expands focus coverage from a
sample transition to the complete field sequence. Exact snapshots compare dates
directly rather than trusting legacy Order equality (DIFF-003).

The 96 retired tests comprise 78 product/component cases (including repeated
callback/spy variants) and 18 empty or unrelated examples. The surviving suite
has 46 tests; this count reduction is not a claim of identical UI coverage.
Legacy files remain recoverable from Git checkpoint `6a8ca52`. The table above
and the baseline table retain their evidence after their source paths disappear.

After retirement: **46 tests passed in en/US and all 46 passed again in en/GB**.
Results: `/private/tmp/CleanStore-cfa-retirement-after-20261025.xcresult` and
`/private/tmp/CleanStore-cfa-retirement-GB-20261025.xcresult`.

Manual checkpoint-4 smoke check by Codex on 25 October 2026, uncommitted working
tree based on `6a8ca52`, isolated iPhone Air/iOS 26.2, UK-style output:
list/detail values; edit prepopulation; row tap to focus and Return from first
to last name; all three shipping choices shown; selecting Two-Day; expiry wheel
changing 25 to 26 October; single-tap save back to updated details; reopening with
saved shipping/expiry values; Back discarding another draft; new order save
returning to a third row with £1.00; relaunch restoring two demo seeds. These
checks passed. Only synthetic edits and the sample's existing fake payment data
were used.

Still unverified manually: every keyboard transition/software-keyboard dismissal,
rendered failure/retry states, full field-by-field round trip, VoiceOver, Dynamic
Type, iPad, rotation and physical devices. The inherited UI-test target remains
skipped in the shared scheme; no automated UI coverage is claimed.

## Checkpoint 5 concurrency evidence

No product behaviour change is intended. Main Actor state publication and the
existing shared-read/ordered-save policies remain in place; refresh merging is
indexed without changing record order or first-match semantics.

| Requirement / risk | Additional automated evidence |
| --- | --- |
| Cancel before starting a read | OrdersFeatureTests.testPreCancelledRefreshDoesNotStartReadAndLaterRefreshWorks: no repository call or error state; subsequent request succeeds. |
| Shared read fails while another caller is cancelled | OrdersFeatureTests.testSharedReadFailureReleasesAllWaitersAndAllowsRetry: one read, both waiters finish, old orders retained, error visible, later retry clears it. |
| Cancel a save already accepted but still queued | OrdersFeatureTests.testQueuedSaveSurvivesCancellationBeforeItsRepositoryCall: earlier write finishes first, accepted second write still commits, later command remains usable. |
| Repeated edits and a new record overtake an old read | OrdersFeatureTests.testLateRefreshKeepsLatestOfRepeatedSavesAndAppendsNewRecord: latest edit wins and new record is retained. |
| Legacy snapshot repeats or omits an ID | OrdersFeatureTests.testRefreshMergePreservesLegacyDuplicateAndMissingIDsWithoutTrapping: first match updated, duplicate and unidentified row retained as before. This does not promise unique SwiftUI row identity for malformed data. |
| Read finishes while a save is pending | OrdersFeatureTests.testRefreshFinishingBeforePendingSaveDoesNotPublishUncommittedDraft: old value until commit, then saved value. |
| Cancelled ViewModel refresh handle is cleared | ListOrdersViewModelTests.testCancelledRefreshHandleIsReleasedAndRetryCanLoad: initial cancellation starts no read and retry is not stranded on the old handle. |
| List screen disappears during shared read | ListOrdersViewModelTests.testReadSurvivesListReleaseAndCancellationWithoutRetainingScreen: ViewModel deallocates; read completes and a replacement screen observes the result. |

The existing save-failure, duplicate-submission, stale-editor-completion,
editor-release and real-repository tests remain active. The tests control
suspension order; they are not a performance benchmark or proof against every
possible schedule. Real SQLite cancellation-after-admission and failed-save
rollback fault injection remain separately unverified.

Checkpoint 5 verification: 46 baseline tests passed before editing; all 54
replacement tests passed in en/US and en/GB afterwards. Complete concurrency
checking is now persisted in both project configurations; the Release Simulator
build also passed. Final evidence:
`/private/tmp/CleanStore-cfa-checkpoint5-verified-US.xcresult`,
`/private/tmp/CleanStore-cfa-checkpoint5-verified-GB.xcresult` and
`/private/tmp/CleanStore-cfa-checkpoint5-Release.xcresult`.
This does not add automated UI coverage or close the manual acceptance list.
