## Why

While unit and request specs cover individual components (484 examples, 0 failures), there are no end-to-end integration tests verifying critical user paths that span multiple components. A broken interaction between Telegram webhook → message handler → intent classification → document creation wouldn't be caught until it hits production. Additionally, there's no code coverage measurement, no CI pipeline, and no coverage threshold enforcement.

## What Changes

- Integration test suite covering critical user paths that span multiple components
- SimpleCov configuration with 80% minimum coverage threshold
- WebMock/VCR setup for deterministic external service stubbing
- CI pipeline configuration (GitHub Actions) running full test suite with coverage

## Capabilities

### New Capabilities

- `integration-test-critical-paths`: End-to-end tests for critical user journeys spanning multiple components
- `coverage-reporting`: SimpleCov configuration with threshold enforcement and CI integration

### Modified Capabilities

<!-- Existing test infrastructure enhanced with coverage tooling -->

## Impact

- **New files**: `spec/integration/` directory with path-specific spec files, `.github/workflows/ci.yml`, `spec/support/simplecov.rb`
- **Modified files**: `spec/rails_helper.rb` (SimpleCov require), `Gemfile` (simplecov gem if not present)
- **Dependencies**: `simplecov` gem (test group)
