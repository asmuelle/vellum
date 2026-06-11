# AGENTS.md — Operating Manual for Vellum

## Project Snapshot

Vellum is a private family medical-record vault for iOS: photograph lab results,
prescriptions, and discharge papers; extract, trend, and explain them — entirely
on-device. Not one page ever leaves the phone. The payer is the sandwich-generation
caregiver (35–60) managing records for themselves plus aging parents; the family
plan ($69.99/yr, 5 profiles) is the hero SKU. Zero inference COGS (deterministic
parsers + Apple Foundation Models) is the structural cost wedge against per-page
cloud-vision competitors. Pipeline status: **recommended** (#5 of 9 edge-AI finalists).

## Read First

| Doc | What it gives you |
|---|---|
| `README.md` | Research dossier: concept, market evidence, adversarial review, tech stack. Do not edit. |
| `DESIGN.md` | Architecture, module map, data model, flows, milestones M0–M3, risks. |
| `TOOLS.md` | Command reference, env vars, CI behavior, AI harness notes. |

## Commands

`just` is the single source of truth. Never run raw `xcodebuild`/`swiftlint` directly.

| Recipe | Purpose |
|---|---|
| `just` | List all recipes |
| `just bootstrap` | Generate Xcode project (XcodeGen) + resolve SPM packages |
| `just build` | Build the Vellum scheme for the iOS Simulator |
| `just test` | Run the test suite on the iPhone 16 simulator (falls back to the first available iPhone) |
| `just lint` | SwiftLint over all sources (zero-warnings policy; skips with a notice when swiftlint is absent) |
| `just format` | SwiftFormat in place |
| `just ci` | Full gate: lint + build + test (CI runs exactly this) |

All build/test recipes fail with guidance if the project is not yet bootstrapped
(`project.yml` / `Vellum.xcodeproj` missing). The domain engine also runs headless:
`swift test` at the repo root exercises every package on macOS without Xcode project
generation.

## Repo Layout

```
README.md            research dossier (read-only)
AGENTS.md            this file
DESIGN.md            architecture + milestones
TOOLS.md             commands, env vars, CI, harness notes
justfile             command surface
project.yml          XcodeGen spec — app target 'Vellum', iOS 26 baseline
Package.swift        one SPM package (VellumKit) holding every Vellum* target
App/                 VellumApp shell sources (composition root, navigation)
Packages/            one directory per module (VellumCore, VellumParsing, ...)
  VellumCore/Sources + Tests, etc.
Fixtures/            synthetic golden lab printouts (+ expected/*.json specs)
.swiftlint.yml, .swiftformat   tool configs (strict)
.claude/settings.json  harness permissions + format/lint hooks
.github/workflows/ci.yml  CI with bootstrap guard
```

`Vellum.xcodeproj` is generated and gitignored — never hand-edit or commit it;
change `project.yml` and re-run `just bootstrap` instead.

## Architecture Summary

A strictly one-directional on-device pipeline: **capture → deterministic parse →
(on-device LLM fallback) → per-value human confirmation → encrypted vault →
surfaces (trends, ask-your-records RAG, template-grounded explanations)**. Each
stage is its own SPM package with `VellumCore` (domain types, analyte catalog,
unit conversions) at the root and the `VellumApp` XcodeGen shell as composition
root. Module map (details in DESIGN.md): `VellumCore`, `VellumCapture`,
`VellumParsing`, `VellumExtraction`, `VellumReview`, `VellumVault`,
`VellumTrends`, `VellumAsk`, `VellumExplain`, `VellumDesignSystem`, `VellumApp`.

## Coding Standards

- Swift 6, strict concurrency (`-strict-concurrency=complete`); no `@unchecked Sendable` without a written justification comment.
- Files < 800 lines, functions < 50 lines; split before you exceed.
- Immutability by default: `let`, value types, no shared mutable state outside actors.
- Explicit error handling at every boundary: typed `throws` or `Result`; never `try!`/`try?`-and-forget on parse, store, or model calls. Parser misses are values, not exceptions.
- No hardcoded secrets — and Vellum needs none at runtime; adding any networked dependency violates a product invariant (below) and requires a DESIGN.md amendment first.
- Conventional commits: `feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`.
- Format with `just format`, lint with `just lint` before declaring work done (hooks also run swiftformat/swiftlint on every edit).

## Testing Policy

- TDD: write the failing test first (RED → GREEN → REFACTOR). Target 80%+ coverage; Swift Testing preferred, XCTest where UI testing requires it.
- AAA pattern (Arrange–Act–Assert) with behavior-describing names.
- What matters most for THIS product, in order:
  1. **Golden-fixture parser tests** — real-format (de-identified, synthetic-value) Quest/Labcorp/Epic printouts in `Fixtures/`; every deterministic parser change must keep all fixtures byte-exact on extracted fields.
  2. **Unit-conversion tests** — every supported analyte conversion (mg/dL↔mmol/L etc.) round-trips against the static table; no tolerance fudging.
  3. **Invariant tests** — confirmation gating, backup exclusion, file protection, no-egress (see invariants below; each must have an automated test).
  4. **Snapshot tests** for the explanation templates (FDA CDS-exemption wording is load-bearing).
  5. UI tests for the capture → confirm → trend happy path.

## PRODUCT INVARIANTS (non-negotiable, each must stay testable)

1. **No page ever leaves the device.** No networking code in any module: CI/lint forbids `URLSession`, `Network`, and third-party HTTP imports repo-wide (allowlist is empty; StoreKit purchase flow is the sole Apple-mediated exception). The full capture→trend→ask loop must pass UI tests in airplane mode.
2. **Deterministic before LLM, always.** Every document first runs the registered regex/table parsers (Quest, Labcorp, Epic in v1). `VellumExtraction` (AFM) may only run when the deterministic registry reports a miss or sub-threshold coverage, and every `ExtractedValue` records `extractionMethod: deterministic | llm`. A test asserts the LLM path is never invoked on any golden fixture that a deterministic parser claims.
3. **Mandatory per-value human confirmation.** Nothing enters trends, RAG, or explanations unconfirmed. Enforced at the type level: `LabResult` is constructible only via a `ReviewReceipt` minted inside `VellumReview`'s confirmation UI flow. `VellumTrends`/`VellumAsk`/`VellumExplain` accept `LabResult` only — never `ExtractedValue`.
4. **Unit normalization in code, never in the model.** Conversions live in `VellumCore`'s static table. The LLM schema captures raw value + raw unit verbatim from the page; any normalized value emitted by a model is discarded.
5. **Backup-excluded encrypted store.** GRDB/SQLite + page images under `NSFileProtectionComplete`, vault directory `isExcludedFromBackup = true`. A test asserts both attributes on the live store URL at startup.
6. **Explanations are template-grounded (FDA CDS exemption).** The model only fills slots against the confirmed structured record and must cite the on-screen reference range; no diagnosis, dosing, or treatment language. Templates are snapshot-tested; copy changes are reviewed against App Review 1.4.1.
7. **Graceful degradation below the Apple Intelligence device floor.** Capture → deterministic parse → confirm → trend must work on every iOS 26 device with no AFM available; LLM fallback and Q&A gate on availability, never crash or block.
8. **Honest privacy copy.** v1 ships single-device, no sync. If CloudKit Advanced Data Protection sync ever ships, copy says "end-to-end encrypted — we can never read it", never "never uploaded".

## Definition of Done

- [ ] Tests written first; `just ci` green locally
- [ ] 80%+ coverage on changed modules; golden fixtures untouched or deliberately re-blessed with rationale in the commit
- [ ] No invariant weakened; new code paths covered by an invariant test where applicable
- [ ] Files < 800 lines, functions < 50, no force-unwraps in production code
- [ ] Conventional commit message; docs (DESIGN.md/TOOLS.md) updated if architecture or commands changed
- [ ] code-reviewer subagent pass on the diff; security-reviewer pass for anything touching `VellumVault`, capture, or export
