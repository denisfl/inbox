## ADDED Requirements

### Requirement: Code coverage measurement

The test suite SHALL measure code coverage using SimpleCov.

#### Scenario: Coverage report generated

- **WHEN** the full test suite runs
- **THEN** a coverage report SHALL be generated in `coverage/` directory

#### Scenario: Minimum coverage threshold

- **GIVEN** SimpleCov is configured with 80% minimum threshold
- **WHEN** coverage falls below 80%
- **THEN** the test suite SHALL fail with a message indicating the gap

### Requirement: CI pipeline

The project SHALL have a CI pipeline that runs tests and enforces coverage.

#### Scenario: CI runs on push

- **WHEN** code is pushed to any branch
- **THEN** GitHub Actions SHALL run the full test suite with coverage measurement

#### Scenario: CI failure blocks merge

- **WHEN** tests fail or coverage is below threshold
- **THEN** the CI pipeline SHALL report failure
