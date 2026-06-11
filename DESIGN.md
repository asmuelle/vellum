# DESIGN.md — Vellum

## Thesis

Photographed paper is the canonical never-cloud medical data, and as of WWDC26 a
phone can parse it locally for free — unlimited scanning is uneconomic for every
per-page cloud-vision rival. The unserved wedge is not "AI health records"; it is
the sandwich-generation caregiver managing paper across multiple family profiles,
a payer with ~$10K/yr demonstrated out-of-pocket spend. Vellum wins by being the
only product that is simultaneously trustworthy (deterministic parsers + mandatory
per-value confirmation + provenance), private (zero egress, provable), and free to
operate at the margin (zero inference COGS makes the family and lifetime SKUs safe).

## Architecture

### Pipeline (capture → on-device inference → store → surface)

```
VisionKit camera ──► Vision OCR ──► Deterministic parsers ──┐ hit
   (capture)        (table-aware,    (Quest / Labcorp /     ├──► ExtractedValues ──► Per-value human ──► Encrypted vault ──► Surfaces
                     bounding boxes)  Epic regex/tables)    │      (tagged with      confirmation        (GRDB/SQLite,       · Trends (Swift Charts)
                                            │ miss          │       method +         (VellumReview;       FileProtection-    · Ask (local RAG)
                                            ▼               │       confidence +     mints LabResult)     Complete,          · Explain (templates)
                                     AFM 3 @Generable ──────┘       page bbox)                            backup-excluded)
                                     (OCR TEXT in, never pixels)
```

Strictly one-directional. No stage reaches back, and nothing downstream of
confirmation ever sees an unconfirmed value (enforced by type: only `VellumReview`
can mint a `LabResult` via `ReviewReceipt`).

### Cost discipline ladder

1. **Deterministic code (always first, free, every device):** regex/table parsers
   for the top US lab formats; unit normalization from a static table; reference-range
   comparison; trend math. This layer is also the durable moat — a parser library
   for messy US lab paper compounds; a prompt does not.
2. **Cheap on-device model (fallback only, free, device-gated):** AFM 3 with
   `@Generable` typed schemas fed OCR *text*; optional task-specific LoRA via
   Apple's adapter toolkit. Used only on deterministic miss or sub-threshold
   coverage; output goes through the exact same confirmation gate.
3. **Frontier/cloud model: never.** Zero inference COGS is the business model and
   "no page ever uploaded" is the brand. There is no tier 3.

### Module map (local SPM packages + XcodeGen app shell)

| Package | Responsibility | Depends on |
|---|---|---|
| `VellumCore` | Domain types, analyte catalog, unit-conversion table, errors. Pure, no I/O | — |
| `VellumCapture` | Document camera (VisionKit), Vision `RecognizeDocumentsRequest` OCR → `OCRPage` (lines, table cells, bounding boxes) | Core |
| `VellumParsing` | Deterministic parser registry (Quest, Labcorp, Epic); coverage scoring; format detection | Core |
| `VellumExtraction` | AFM 3 fallback, `@Generable` schemas, device-availability gating | Core |
| `VellumReview` | Per-value confirmation UI; side-by-side page crop vs proposed value; sole minter of `LabResult` | Core, DesignSystem |
| `VellumVault` | GRDB/SQLite store; encrypted page images; `NSFileProtectionComplete`; backup exclusion; export | Core |
| `VellumTrends` | Longitudinal series + Swift Charts from confirmed `LabResult`s only | Core, Vault, DesignSystem |
| `VellumAsk` | Local RAG: NLContextualEmbedding index over confirmed records + OCR text; Spotlight tooling; answers always cite source documents | Core, Vault |
| `VellumExplain` | Template-grounded plain-English explanations (FDA CDS-exempt wording) | Core, Vault |
| `VellumDesignSystem` | Tokens, typography, semantic state colors, shared components | — |
| `VellumApp` | XcodeGen target: composition root, navigation, profiles, StoreKit 2 paywall | all |

## Data Model Sketch

- **Profile** — id, displayName, relationship (self/parent/child/partner/other), dateOfBirth, accentColor, createdAt. Multi-profile is the paywall boundary.
- **Document** — id, profileId, kind (labReport/prescription/dischargeSummary/eob/other), capturedAt, detectedFormat (quest/labcorp/epic/unknown), parseStatus (captured/parsed/awaitingReview/reviewed), pageCount.
- **Page** — id, documentId, index, encryptedImageRef, ocrText, ocrConfidence, tableCellMap.
- **ExtractedValue** (proposal, pre-confirmation) — id, documentId, pageId, boundingBox, analyteRaw, valueRaw, unitRaw, refRangeRaw, collectedAtRaw, extractionMethod (deterministic/llm), confidence, reviewState (pending/confirmed/corrected/rejected).
- **LabResult** (confirmed observation; the only thing trends/RAG/explain may read) — id, profileId, analyteId, value (canonical unit, converted in code), unit, refLow, refHigh, collectedAt, provenance (documentId, pageId, boundingBox, extractionMethod), reviewReceiptId.
- **Analyte** (bundled static catalog) — id, canonicalName, aliases, loincCode, canonicalUnit, conversions [(fromUnit, factor, offset)], displayPrecision.
- **Medication** — id, profileId, nameRaw, dose, prescriber, startDate, sourceDocumentId, reviewState (same gate as lab values).
- **RagChunk** — id, profileId, sourceDocumentId, text, embedding, kind (confirmedRecord/ocrContext). Answers must cite sourceDocumentId.

## Key Flows

### 1. Capture → trend (the core loop)

1. Caregiver taps Scan on Dad's profile → VisionKit camera captures pages.
2. Vision OCR produces text + table cells + bounding boxes per page.
3. Format detector tries the deterministic registry; Quest parser claims the page and emits `ExtractedValue`s tagged `deterministic` with per-value bounding boxes.
4. Review screen: each value shown beside its cropped source-page region; user confirms, corrects, or rejects each one (bulk-confirm allowed only for deterministic, high-confidence rows — never for LLM rows).
5. Confirmed values are unit-normalized in code, minted as `LabResult`s, and written to the encrypted vault.
6. The analyte's trend chart updates; out-of-range points use the printed reference range from that document, not a hardcoded one.

### 2. Deterministic miss → LLM fallback

1. An unfamiliar hospital printout fails format detection (coverage below threshold).
2. If AFM is available on-device, `VellumExtraction` runs the `@Generable` schema over the OCR text; values come back tagged `llm` with model confidence; raw unit captured verbatim, no model-side normalization.
3. If AFM is unavailable (pre-iPhone 15 Pro), the document is stored as a searchable scan with a "manual entry" affordance — never a crash, never a silent drop.
4. All LLM rows require individual confirmation (no bulk-confirm) before entering the vault.

### 3. Add a family profile (the conversion event)

1. User taps "+ Add family member" to create Mom's profile.
2. Free tier covers one profile with unlimited scanning and storage; the second profile presents the family-plan paywall ($69.99/yr hero SKU; $179 lifetime).
3. On subscribe, the profile is created locally; no account, no email, no server — StoreKit 2 entitlement is the only "login".

### 4. Ask your records

1. "When was Dad's last tetanus shot?" → query embedded locally, retrieved against `RagChunk`s scoped to Dad's profile.
2. AFM composes an answer constrained to retrieved chunks; the answer card always shows the source document(s) with a tap-through to the page image.
3. No retrieval hit → "I couldn't find that in Dad's records" — never a generated guess. Feature is gated on AFM availability and on the paid tier.

### 5. Explain a value

1. User taps a confirmed potassium result → `VellumExplain` selects the matching template ("what this analyte measures" + "where this value sits vs. the printed range").
2. AFM fills template slots from the confirmed record only; output cites the on-screen reference range; banned-phrase lint (diagnose/dose/treat/stop taking) runs over the output before display.
3. Footer on every explanation: "Not medical advice. Talk to your clinician." Snapshot tests pin the template wording (FDA CDS exemption + App Review 1.4.1).

## Product & Visual Design Direction

**Archival paper-trust.** The app should feel like a meticulously kept family
document folio, not a clinical dashboard or an AI toy — calm, legible, and proud
of its provenance. Surfaces in warm vellum cream (`#F7F3EA`-family) with subtle
paper grain on document views; ink charcoal (near-black, warm) for text. **New
York (serif)** for record titles, analyte names, and large trend numerals — the
typographic cue of paper records — with **SF Pro** for UI chrome; generous
numeral-first hierarchy on trend screens. Color is strictly semantic, never
decorative: amber = awaiting confirmation, deep teal = confirmed/in-range,
claret = out-of-range, slate = unparsed scan. Confirmation interactions borrow
from stamping/ledger metaphors (a satisfying per-value "verified" mark), and
every value's tap-through-to-source-crop is a first-class visual moment — the
provenance UI *is* the brand. Accessibility floor: Dynamic Type through XL,
WCAG AA contrast on all semantic colors, full VoiceOver labels on charts.

## Milestones

### M0 — Bootstrap (make `just ci` green with code)

- `project.yml` defining the `Vellum` app target (iOS 26 baseline) + all SPM packages from the module map, each with a placeholder test.
- `just bootstrap && just ci` passes locally and in CI (guard flips from skip to run).
- `.swiftlint.yml` + `.swiftformat` configs committed; strict concurrency on everywhere.
- **Accept:** CI green on a fresh clone with only Xcode + brew tools installed; every package has ≥1 passing test.

### M1 — Thin vertical slice (deterministic-only, single profile)

- Capture a single-page Quest CBC/CMP printout → Vision OCR → Quest + Labcorp deterministic parsers → per-value confirmation screen → confirmed `LabResult`s in the encrypted vault → one Swift Charts trend for one analyte across ≥2 documents. No LLM anywhere in this milestone.
- Golden fixture corpus (synthetic values) for Quest and Labcorp formats with exact-match parser tests.
- **Accept:** end-to-end UI test passes in airplane mode; 100% of extracted values pass through the review screen (invariant test); vault store URL asserts `NSFileProtectionComplete` + `isExcludedFromBackup`; unit-conversion table fully tested; ≥80% coverage on Parsing/Core/Vault.

### M2 — Trust layer

- Provenance everywhere: tap any trend point → source-page crop with highlighted bounding box.
- AFM fallback path (`VellumExtraction`) behind deterministic miss, with `llm` tagging, no-bulk-confirm rule, and graceful no-AFM degradation; Epic-printout parser added.
- Privacy proof: repo-wide no-network lint in CI (forbidden-import check), airplane-mode UI test suite, and an in-app "How private is this?" screen stating exactly what never leaves the device.
- Template-grounded explanations with banned-phrase lint and snapshot-pinned wording.
- **Accept:** every trend point traceable to a confirmed value with visible crop; forbidden-import check green; explanation snapshots reviewed against FDA CDS-exemption criteria; LLM rows provably never bulk-confirmed (test).

### M3 — Monetization wiring

- StoreKit 2: free tier = one profile, unlimited capture + storage + search of raw scans; paid = multi-profile, trends, Ask, Explain. Family $69.99/yr (hero), individual $39.99/yr, lifetime-family $179.
- Paywall fires exactly at second-profile creation (the natural caregiver conversion event); restore purchases; no accounts.
- **Accept:** StoreKitTest-covered purchase/restore/expiry paths; paywall UI test on second-profile add; free tier verified genuinely unlimited for capture (no scan counters anywhere in code); App Store privacy nutrition label drafts to "Data Not Collected".

## Risks & Mitigations (from the adversarial review)

| # | Risk | Mitigation |
|---|---|---|
| 1 | **Accuracy: 3B-class models ~90% per-field → a 20-analyte panel almost certainly contains an error; a transposed potassium in a trend is dangerous.** | Deterministic parsers first (near-perfect on known formats); LLM only as tagged fallback; mandatory per-value confirmation with source-crop UI; no bulk-confirm on LLM rows; provenance on every stored value. Position the review screen as the feature ("you verified this"), not friction. |
| 2 | **"Never uploaded" contradicts family sync (records must reach the sister's phone).** | v1 is deliberately single-device, multi-profile-on-one-phone (the caregiver holds the folio — matches the paper workflow). If sync ships later: CloudKit Advanced Data Protection, copy switched to "end-to-end encrypted — we can never read it" (invariant #8). Never run our own relay. |
| 3 | **The platform moat is months old and shared; Apple may sherlock the explain layer.** | The durable moat is the deterministic parser library for messy US lab paper + the multi-profile caregiver workflow — neither ships in an Apple framework. Treat AFM as a commodity; concentrate engineering in `VellumParsing` and `VellumReview`. |
| 4 | **Device floor: aging parents' phones can't run AFM (iPhone 15 Pro+ only).** | The full capture→parse→confirm→trend loop is deterministic and runs on every iOS 26 device (invariant #7). v1's single-device model means the parent's phone never needs the app at all — the caregiver's phone does the work. |
| 5 | **Regulatory/App Review: free-form lab "explanations" walk the FDA CDS line; one wrong "normal" screenshot is existential.** | Template-grounded slots over confirmed values only, citing the printed reference range; banned-phrase lint; snapshot-pinned copy; persistent not-medical-advice footer; the app never classifies a value as normal/abnormal beyond comparing it to the range printed on the user's own document. |
| 6 | **Distribution: search owned by free MyChart/insurer apps; CAC vs $40–70 LTV.** | Build for the caregiver referral loop (family plan inherently multi-user); make the provenance/privacy UI screenshot-able; target "lab results binder/folder" caregiver intent, not "medical records"; B2B2C (eldercare agencies) once per-seat zero COGS can be pitched. |
