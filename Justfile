set shell := ["zsh", "-cu"]

project := "Docket/Docket.xcodeproj"
scheme := "Docket"
simulator := env_var_or_default("DOCKET_SIMULATOR", "iPhone 17 Pro")
simulator_os := env_var_or_default("DOCKET_SIMULATOR_OS", "latest")
derived_data := env_var_or_default("DOCKET_DERIVED_DATA", "/tmp/docket-board-derived")
test_destination := "platform=iOS Simulator,name=" + simulator + ",OS=" + simulator_os

# List the available project commands.
default:
    @just --list

# Confirm the local Xcode tools and selected simulator settings.
doctor:
    @command -v xcodebuild
    @xcrun --find swift-format
    @echo "Simulator: {{simulator}} ({{simulator_os}})"
    @echo "DerivedData: {{derived_data}}"

# Show destinations Xcode can use for the Docket scheme.
destinations:
    xcodebuild -project "{{project}}" -scheme "{{scheme}}" -showdestinations

# Compile the app for a generic iOS Simulator without signing.
build:
    xcodebuild build \
        -project "{{project}}" \
        -scheme "{{scheme}}" \
        -destination "generic/platform=iOS Simulator" \
        -derivedDataPath "{{derived_data}}/build" \
        CODE_SIGNING_ALLOWED=NO

# Build a signed simulator app and unit-test bundle without running tests.
build-tests:
    xcodebuild build-for-testing \
        -project "{{project}}" \
        -scheme "{{scheme}}" \
        -destination "{{test_destination}}" \
        -derivedDataPath "{{derived_data}}/tests"

# Run the complete Docket unit-test target.
test: build-tests
    xcodebuild test-without-building \
        -project "{{project}}" \
        -scheme "{{scheme}}" \
        -destination "{{test_destination}}" \
        -derivedDataPath "{{derived_data}}/tests" \
        -only-testing:DocketTests

# Run one unit-test class or method, e.g. `just test-one ModelConversionTests/testRestaurantRoundTrip`.
test-one selector: build-tests
    xcodebuild test-without-building \
        -project "{{project}}" \
        -scheme "{{scheme}}" \
        -destination "{{test_destination}}" \
        -derivedDataPath "{{derived_data}}/tests" \
        -only-testing:"DocketTests/{{selector}}"

# Format changed and untracked Swift sources with Xcode's swift-format.
format:
    #!/usr/bin/env zsh
    set -euo pipefail
    files=("${(@f)$(git diff --name-only --diff-filter=ACMR -- '*.swift')}" "${(@f)$(git ls-files --others --exclude-standard -- '*.swift')}")
    if (( ${#files} == 0 )); then
        echo "No changed Swift files."
        exit 0
    fi
    xcrun swift-format format --configuration .swift-format --in-place --parallel "${files[@]}"

# Check changed and untracked Swift sources without changing files.
format-check:
    #!/usr/bin/env zsh
    set -euo pipefail
    files=("${(@f)$(git diff --name-only --diff-filter=ACMR -- '*.swift')}" "${(@f)$(git ls-files --others --exclude-standard -- '*.swift')}")
    if (( ${#files} == 0 )); then
        echo "No changed Swift files."
        exit 0
    fi
    xcrun swift-format lint --configuration .swift-format --strict --parallel "${files[@]}"

# Check the working tree for whitespace errors.
check:
    git diff --check

# Run the non-mutating checks and complete unit-test target.
verify: check test
