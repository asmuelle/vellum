# Vellum — command surface. Agents and humans use these recipes, never raw xcodebuild.

app := "Vellum"

# Preferred simulator is the iPhone 16; fall back to the first available
# iPhone (e.g. iPhone 17 Pro on newer Xcodes) so CI and dev machines with
# different runtimes both work.
sim := `xcrun simctl list devices available 2>/dev/null | sed -nE 's/^ *(iPhone[^(]*[^ (]) *\(.*/\1/p' | grep -x "iPhone 16" || xcrun simctl list devices available 2>/dev/null | sed -nE 's/^ *(iPhone[^(]*[^ (]) *\(.*/\1/p' | head -n 1`

# List all recipes
default:
    @just --list --unsorted

# Generate the Xcode project via XcodeGen and resolve SPM dependencies
bootstrap:
    @command -v xcodegen >/dev/null 2>&1 || { echo "error: xcodegen not installed. Run: brew install xcodegen"; exit 1; }
    @test -f project.yml || { echo "error: project.yml not found — this is still a docs-only scaffold."; echo "Create project.yml (app target '{{app}}' + SPM packages, see DESIGN.md milestone M0), then re-run: just bootstrap"; exit 1; }
    xcodegen generate
    xcodebuild -resolvePackageDependencies -project {{app}}.xcodeproj -scheme {{app}}

# Build the app for the iOS Simulator
build: _require-bootstrap
    xcodebuild build -project {{app}}.xcodeproj -scheme {{app}} -destination 'platform=iOS Simulator,name={{sim}}' -quiet

# Run the test suite on the iPhone 16 simulator
test: _require-bootstrap
    xcodebuild test -project {{app}}.xcodeproj -scheme {{app}} -destination 'platform=iOS Simulator,name={{sim}}' -quiet

# Lint all Swift sources (zero-warnings policy; skips gracefully when swiftlint is absent)
lint: _require-bootstrap
    @if command -v swiftlint >/dev/null 2>&1; then swiftlint; else echo "notice: swiftlint not installed — skipping lint (brew install swiftlint to enable)"; fi

# Format all Swift sources in place
format:
    @command -v swiftformat >/dev/null 2>&1 || { echo "error: swiftformat not installed. Run: brew install swiftformat"; exit 1; }
    swiftformat .

# verify formatting (swiftformat --lint); CI gate
format-check:
    swiftformat --lint .

# Full local gate: lint + build + test (CI runs exactly this)
ci: lint build test format-check

# (internal) Fail with guidance when the project has not been bootstrapped yet
_require-bootstrap:
    @test -f project.yml || { echo "error: project.yml not found — this is still a docs-only scaffold."; echo "See DESIGN.md milestone M0, then run: just bootstrap"; exit 1; }
    @test -d {{app}}.xcodeproj || { echo "error: {{app}}.xcodeproj not found. Run: just bootstrap"; exit 1; }
