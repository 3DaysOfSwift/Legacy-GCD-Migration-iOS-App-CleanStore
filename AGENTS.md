# CleanStore migration

CFA workflow: established-product maintenance

Use CFA AI Toolkit for iOS v0.3's `swift-concurrency-migration` skill.
The local toolkit is in the sibling `CFA AI Toolkit for iOS` directory.
Read its skill and required references before implementation; do not substitute
an older installed plugin's rules. See `MIGRATION.md` for toolkit provenance.

Preserve the existing product's design, navigation, data and behaviour. This is
not a new-app template exercise. Do not add themes, tabs, networking or durable
storage simply because the architecture supports them. Keep existing bundle IDs.

Maintain `MIGRATION_BEHAVIOUR_CONTRACT.md` and `MIGRATION.md` after each checkpoint.
Separate architectural restructuring from concurrency conversion. Record exposed
defects and obtain approval for product changes instead of silently fixing them.
Do not remove legacy tests before equivalent requirement coverage exists.

The original app is UIKit/storyboard-based with an iOS 15 deployment target.
Matthew Thomas approved SwiftUI and an iOS 17 minimum on 25 October 2026,
preserving the existing design and workflows. Keep the original single-window
behaviour; do not introduce multi-window selection semantics in this checkpoint.
Never claim a build proves tests passed or that automated tests prove visual parity.

Keep build products and result bundles outside the repository. Run destructive
storage tests on an isolated Simulator, not a developer's populated app install.
Provide explicit Git checkpoint commands; do not publish a PR to the original
upstream repository without authorization.
