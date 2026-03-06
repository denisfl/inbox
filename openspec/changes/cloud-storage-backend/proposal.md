---
id: cloud-storage-backend
title: Cloud Storage Backend (Dropbox / Google Drive / S3)
status: proposed
created: 2025-07-26
---

## Problem

All files (audio recordings, images, PDFs, attachments) are stored on-device via ActiveStorage's Disk service. On Raspberry Pi with a limited SD card / USB drive, storage fills up quickly -- especially with audio files (a 10-minute voice note is ~5-10 MB WAV after conversion). There is no off-device backup for attachments; if the drive fails, all files are lost.

Users who already pay for cloud storage (Dropbox, Google Drive, iCloud, S3) cannot leverage that space for their Inbox files.

## Solution

Allow the user to configure an external cloud storage service as the ActiveStorage backend. Files are uploaded to and served from the chosen cloud provider instead of local disk. The local disk remains available as a fallback / default.

### Supported Providers (priority order)

1. **Dropbox** -- most personal users have it; simple OAuth + API
2. **Google Drive** -- common; uses Google Cloud Storage (GCS) under the hood
3. **Amazon S3** / **S3-compatible** (MinIO, Backblaze B2, Cloudflare R2) -- for power users
4. **Local disk** -- current default, always available

### User Experience

1. Admin opens Settings page (new route: `/settings/storage`)
2. Selects provider from dropdown (Local / Dropbox / Google Drive / S3)
3. Authenticates via OAuth flow (Dropbox, Google) or enters credentials (S3)
4. Clicks "Test Connection" -- app verifies read/write access
5. Clicks "Save" -- ActiveStorage switches to the new backend
6. Existing local files optionally migrated to cloud (background job)

## Capabilities

### New Capabilities

- `storage-settings-ui`: Settings page for configuring cloud storage provider, credentials, and connection test
- `storage-dropbox`: Dropbox integration via OAuth 2.0 + Dropbox API v2. Custom ActiveStorage service wrapping the Dropbox SDK
- `storage-google-drive`: Google Drive integration via OAuth 2.0 + Google Cloud Storage. Uses Rails built-in GCS service
- `storage-s3`: S3 / S3-compatible storage. Uses Rails built-in S3 service with custom endpoint support
- `storage-migration-job`: Background job to migrate existing files from one backend to another (e.g., local -> Dropbox)
- `storage-health-check`: Periodic check that cloud storage is reachable; fallback to local disk cache if unavailable

### Modified Capabilities

- `active-storage-config`: `config/storage.yml` dynamically selects the configured service
- `docker-compose`: Add environment variables for storage credentials
- `settings-route`: New `/settings` namespace for app configuration

## Design Decisions

### Why ActiveStorage service layer?

Rails ActiveStorage already abstracts storage backends via service adapters (Disk, S3, GCS, AzureStorage, Mirror). Adding Dropbox requires a custom service class (`ActiveStorage::Service::DropboxService`), but S3 and GCS work out of the box. This keeps the change minimal -- no file upload/download code changes anywhere in the app.

### Why not just S3?

The target user is a single person running Inbox on a Pi at home. They likely have a personal Dropbox or Google Drive account with spare capacity, not an AWS account. S3 is offered as an option for technical users but is not the primary target.

### OAuth vs API keys

Dropbox and Google Drive use OAuth 2.0 for authentication. The app stores refresh tokens encrypted in credentials. For S3, static access keys are used (standard practice).

### File migration

When switching backends, existing files need to be copied. A background job iterates all ActiveStorage blobs, downloads from the old service, and uploads to the new one. Progress is shown on the settings page.

### Offline resilience

If the cloud backend is unreachable (network outage, RPi offline), uploads fail. Options:

- **A) Queue locally, sync later** -- complex but resilient (like Syncthing)
- **B) Fail immediately, show error** -- simple, user retries when online

Recommendation: **Option B** for v1 (simple). Add local queue (Option A) as a future enhancement.

## Non-Goals

- Bidirectional sync (Inbox is the source of truth, not the cloud folder)
- Browsing cloud storage contents from within Inbox
- Multi-cloud mirroring (ActiveStorage Mirror service exists but adds complexity)
- End-to-end encryption of cloud-stored files (rely on provider encryption)
- iCloud integration (no public API for file storage)

## Impact

- **Database**: 1 new table `storage_settings` (provider, credentials_encrypted, active flag)
- **Gems**: `dropbox_api` (~100 KB), `aws-sdk-s3` (already in Rails default Gemfile), `google-cloud-storage` (for GCS)
- **Docker**: New ENV vars for storage config; no new containers
- **Security**: OAuth tokens and S3 keys stored via Rails encrypted credentials or database-level encryption
- **Performance**: Cloud storage adds latency to file uploads/downloads vs local disk. Mitigated by ActiveStorage's redirect-based serving (302 to signed cloud URL)
- **Backward compatibility**: Default remains local disk. No changes for users who don't configure cloud storage

## Open Questions

1. Should we support Nextcloud / WebDAV as a provider? (common in self-hosted community)
2. Should file migration be mandatory or optional when switching providers?
3. Should we cache recently accessed files locally for faster serving?
