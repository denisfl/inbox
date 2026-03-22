## ADDED Requirements

### Requirement: S3 storage adapter

The system SHALL provide a `StorageAdapter::S3` implementation that stores files in an S3 or S3-compatible bucket.

#### Scenario: Upload to S3

- **WHEN** `upload(file_path, key, namespace: :files)` is called
- **THEN** the adapter SHALL upload the file to `<namespace>/<key>` in the configured S3 bucket

#### Scenario: Download from S3

- **WHEN** `download(key, namespace: :files)` is called for an existing object
- **THEN** the adapter SHALL return a Tempfile with the object contents

#### Scenario: Signed URL generation

- **WHEN** `url(key, namespace: :files, expires_in: 1.hour)` is called
- **THEN** the adapter SHALL return a pre-signed S3 URL valid for the specified duration

#### Scenario: S3-compatible endpoint

- **WHEN** the storage setting includes a custom endpoint URL (e.g., MinIO, Backblaze B2)
- **THEN** the adapter SHALL use the custom endpoint instead of the default AWS endpoint

#### Scenario: Test connection

- **WHEN** `test_connection()` is called with valid credentials
- **THEN** the adapter SHALL upload a test object, read it back, delete it, and return `{ ok: true }`

#### Scenario: Test connection failure

- **WHEN** `test_connection()` is called with invalid credentials
- **THEN** the adapter SHALL raise an error with a descriptive message
