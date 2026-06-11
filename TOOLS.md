# TOOLS.md — Command Surface & Tooling

## just Recipes

| Recipe | What it does | When to run |
|---|---|---|
| `just` | Lists all recipes | Orientation |
| `just bootstrap` | Runs `xcodegen generate` from `project.yml`, then resolves SPM packages | After cloning, after editing `project.yml`, or whenever `Vellum.xcodeproj` is missing (it is gitignored — always regenerated) |
| `just build` | `xcodebuild build`, scheme `Vellum`, iOS Simulator destination | Sanity-check compilation during development |
| `just test` | `xcodebuild test` on the iPhone 16 simulator (falls back to the first available iPhone) | After every change; TDD inner loop |
| `just lint` | `swiftlint` over the repo (zero warnings); prints a notice and skips when swiftlint is not installed | Before committing; CI enforces |
| `just format` | `swiftformat .` in place | Before committing (also runs per-edit via hooks) |
| `just ci` | `lint` + `build` + `test` | The full local gate; identical to CI |

Pre-bootstrap behavior: `bootstrap`, `build`, `test`, and `lint` detect a missing
`project.yml`/`.xcodeproj` and exit 1 with instructions instead of producing
confusing xcodebuild errors. `format` is always safe to run.

Prerequisites (macOS): Xcode 26+ with the iOS 26 SDK and any iPhone simulator
(iPhone 16 preferred, newer models work), plus
`brew install just xcodegen swiftformat swiftlint`.

Headless inner loop: `swift test` at the repo root runs all package suites on
macOS (no simulator, no Xcode project) — the fastest TDD cycle for engine work.

## External Data Sources / APIs

**None at runtime — by design.** "No page ever uploaded" is product invariant #1
(see AGENTS.md). The app ships with no networking code and no API keys. The only
network traffic the product ever generates is Apple-mediated StoreKit purchases (M3).

Development-time (build/test only, never shipped as network calls):

| Resource | Use | Notes |
|---|---|---|
| Apple FoundationModels + adapter toolkit | AFM 3 `@Generable` extraction fallback; optional task-specific LoRA for lab extraction | OS-provided, free, on-device only. iOS 27 for image input; we feed OCR **text**, not pixels |
| Vision `RecognizeDocumentsRequest` / VisionKit doc camera | Table-aware OCR + capture | OS framework, all iOS 26 devices |
| LOINC/UCUM-derived analyte + unit table | Bundled static catalog in `VellumCore` | Vendored at build time as a versioned resource; cite source + version in the file header |
| Golden fixture corpus (`Fixtures/`) | Synthetic Quest/Labcorp/Epic-format lab printouts for parser tests | Synthetic values only — never real patient data, even de-identified |

## Required Env Vars

| Name | Purpose |
|---|---|
| — | None. The app must build, test, and run with zero secrets and zero env vars. If a task seems to need one, stop: it almost certainly violates invariant #1. |

## Local Services

None. No Docker, no database server, no backend. The "database" is GRDB/SQLite
inside the app sandbox (`NSFileProtectionComplete`, backup-excluded). Everything
runs in the iOS Simulator.

## CI (.github/workflows/ci.yml)

- Triggers: every `push` and `pull_request`; runs on `macos-15`.
- Steps: checkout → setup `just` → `brew install swiftformat swiftlint` → **bootstrap guard**.
- Bootstrap guard: if `project.yml` does not exist, CI emits a notice and skips
  build/test — so this docs-only scaffold stays green. Once `project.yml` lands
  (milestone M0), CI installs `xcodegen`, runs `just bootstrap`, then `just ci`.
- Keep CI fast: no code signing (simulator only), no archive, no UI-test sharding
  until the suite demands it.

## AI Harness Notes

Hooks active in `.claude/settings.json` (copied verbatim from the iOS scaffold template — do not edit casually):

- **PostToolUse (Write|Edit):** `swiftformat` auto-formats every edited `.swift` file, then `swiftlint` prints the first 10 lint findings for it. Expect your edits to be reformatted under you; re-read before stacking further edits on the same region.
- Permissions pre-allow `just`, `xcodebuild`, `xcrun`, `swift`, `swiftformat`, `swiftlint`, `xcodegen`, and read-only `git` — stay inside `just` recipes and no prompts fire.

Most useful subagents for this repo:

- **tdd-guide** — before any new parser, conversion, or store feature (tests-first is mandatory here; golden fixtures are the spec).
- **code-reviewer** — after every change set, before commit.
- **security-reviewer** — mandatory for anything touching `VellumVault` (encryption, file protection, backup exclusion), capture image handling, data export, or paywall/receipt logic. This is medical data; treat every store-layer diff as security-sensitive.
- **planner** — for milestone-sized work (e.g. the M1 vertical slice) before writing code.
