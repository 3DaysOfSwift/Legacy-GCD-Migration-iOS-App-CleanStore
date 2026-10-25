# CleanStore product behaviour contract

Baseline: `e13b868bda3ad1a5987aadbff249b557c1e82d27`, 25 October 2026.
Paths below are relative to the repository. Test class names match their files
under `CleanStoreTests/Scenes`, `Services` or `Workers`.

Confirmed means explicit tests support intent, not that end-to-end behaviour has
been manually verified. Inferred rows are source evidence requiring acceptance.
Checkpoint 1 adds SwiftUI replacements; the original tests and storage remain.
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
| DIFF-001 | Worker fetch failure becomes `[]`; UI cannot distinguish failed load from empty results. | Existing defect exposed | Preserve baseline pending approval for visible load failure/retry |
| DIFF-002 | Core Data update with unknown ID has no callback on the empty-fetch branch. | Existing defect exposed | Resolve before any continuation bridge; explicit not-found outcome needs tests |
| DIFF-003 | Legacy equality treats sufficiently earlier dates as equal, potentially hiding incorrect test results. | Existing defect exposed | Do not use existing whole-order equality as sole replacement proof; review precise field assertions |
| DIFF-004 | Presenter tests assert US strings but formatters use the current locale. | Environment or flaky evidence | Four tests fail with inherited UK-style output; identical binaries pass all 96 tests in US region. Keep product locale-aware; make replacement tests locale-explicit |
| DIFF-005 | UIKit/iOS 15 → SwiftUI/iOS 17+ changes framework and device support. | Approved scope change | Matthew Thomas approved “Yes—SwiftUI, iOS 17+” on 25 October 2026; implemented in checkpoint 1 |
| DIFF-006 | The original “Same as shipping address” switch has no action or outlet and does not copy the address. | Existing defect exposed | Preserve behaviour for now; address-copying requires a separate decision/test |
| DIFF-007 | Shipping uses a native SwiftUI menu; the date/time wheel expands in the form instead of using a text-field input view. | Framework presentation adaptation | Values and editing workflows retained; manual acceptance pending |

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

## Manual regression record

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
