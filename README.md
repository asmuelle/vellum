# Vellum

> A private family medical-record vault that photographs lab results, prescriptions, and discharge papers, then extracts, trends, and explains them — unlimited capture, and not one page ever uploaded.

**Category:** Edge AI / on-device inference (iOS + Android) 

## Concept

A private family medical-record vault that photographs lab results, prescriptions, and discharge papers, then extracts, trends, and explains them — unlimited capture, and not one page ever uploaded.

## Target User

The sandwich generation (35-60) managing their own records plus aging parents' paperwork across multiple providers; chronic-condition patients tracking labs over years. The caregiver is the payer and the upsell engine.

## Why Edge AI Is Structural (not decoration)

AFM 3 Core Advanced image input plus the free OCRTool parse photographed labs, EOBs, prescriptions, and discharge summaries; @Generable extracts typed records (analyte, value, reference range, date) into longitudinal trend charts; Spotlight local RAG powers 'ask your records' Q&A ('when was Dad's last tetanus shot?'); AFM 3 generates plain-English explanations. Android: ML Kit GenAI Prompt API (text+image) on flagships, multimodal Gemma 3n E4B via LiteRT-LM elsewhere. Structural: medical documents are the canonical never-cloud data — the vault premise collapses if pages transit a server, unlimited scanning is uneconomic for cloud-vision rivals but free here, and 5.1.2(i) forces cloud competitors into ugly consent dialogs this app never shows.

## Why Now (2026 timing)

On-device vision for third-party apps became possible at WWDC26 (AFM 3 image input + OCRTool); mobile local OCR+LLM extraction has zero polished commercial players today; Health & Fitness passed $4B IAP and health-data breach headlines have pre-sold the distrust of cloud record apps.



## Tech Stack

iOS (iOS 26 baseline, iOS 27 for AFM 3 image input, Sept 2026): VisionKit document camera (VNDocumentCameraViewController) for capture; Vision RecognizeDocumentsRequest for table-aware OCR; FoundationModels AFM 3 with @Generable typed schemas (analyte/value/unit/refRange/date) fed OCR TEXT, not raw pixels — use the built-in OCRTool and Spotlight search tool for local RAG Q&A; train a task-specific LoRA adapter with Apple's Foundation Models adapter toolkit for lab extraction; deterministic layer FIRST — regex/table parsers for the top US lab formats (Quest, Labcorp, hospital Epic printouts) with the LLM as fallback, plus a mandatory per-value human-confirmation UI; unit normalization (mg/dL vs mmol/L) in code, never in the model; GRDB/SQLite with NSFileProtectionComplete; NLContextualEmbedding (or EmbeddingGemma converted to Core ML) for the local vector index; Swift Charts for trends; CloudKit with Advanced Data Protection for E2E family sync (and honest 'end-to-end encrypted, we can never read it' copy instead of 'never uploaded'). Android: ML Kit Document Scanner + Text Recognition v2 for OCR; ML Kit GenAI Prompt API (Gemini Nano, image+text) on Pixel 8+/Galaxy S24+ AICore devices; Gemma 3n E2B (not E4B — mid-range RAM) via MediaPipe LLM Inference / LiteRT-LM as the fallback tier, text-only extraction path on devices that can't hold the vision encoder; EmbeddingGemma via LiteRT for RAG embeddings; SQLCipher + Android Keystore. Cross-platform family sync: ship iOS-only family plans in v1; if Android profiles are required, an Automerge/CRDT document store over a dumb zero-knowledge blob relay (client-held keys, libsodium), priced into COGS honestly. Explanations layer: template-grounded output (model fills slots against the verified structured record, cites the reference range shown on-screen) to stay inside the FDA CDS exemption.
