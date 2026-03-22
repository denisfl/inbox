## ADDED Requirements

### Requirement: OAuth manager service

The system SHALL provide an `OAuthManager` service that handles OAuth 2.0 authorization flows for Dropbox, Google Drive, and OneDrive.

#### Scenario: Generate authorization URL

- **WHEN** `OAuthManager.new.authorize_url(:dropbox)` is called
- **THEN** the service SHALL return a URL to the Dropbox OAuth consent page with correct client_id, redirect_uri, and scopes

#### Scenario: Handle callback with authorization code

- **WHEN** `OAuthManager.new.handle_callback(:dropbox, code)` is called with a valid authorization code
- **THEN** the service SHALL exchange the code for access_token and refresh_token, and return them

#### Scenario: Refresh expired access token

- **WHEN** `OAuthManager.new.refresh_access_token(:google_drive, refresh_token)` is called
- **THEN** the service SHALL request a new access_token from the provider's token endpoint and return it with the new expiry time

### Requirement: Provider-specific OAuth configuration

The system SHALL load OAuth client_id and client_secret from ENV variables per provider.

#### Scenario: Dropbox OAuth config

- **WHEN** the Dropbox provider is used
- **THEN** the system SHALL read `DROPBOX_CLIENT_ID` and `DROPBOX_CLIENT_SECRET` from ENV

#### Scenario: Google Drive OAuth config

- **WHEN** the Google Drive provider is used
- **THEN** the system SHALL read `GOOGLE_DRIVE_CLIENT_ID` and `GOOGLE_DRIVE_CLIENT_SECRET` from ENV

#### Scenario: OneDrive OAuth config

- **WHEN** the OneDrive provider is used
- **THEN** the system SHALL read `ONEDRIVE_CLIENT_ID` and `ONEDRIVE_CLIENT_SECRET` from ENV

#### Scenario: Missing OAuth client config

- **WHEN** a provider's client_id or client_secret ENV var is not set
- **THEN** the system SHALL raise a descriptive error when the OAuth flow is initiated

### Requirement: OAuth routes

The system SHALL provide OAuth authorize and callback routes under `/settings/storage/oauth/:provider/`.

#### Scenario: Authorize redirect

- **WHEN** the user visits `GET /settings/storage/oauth/dropbox/authorize`
- **THEN** the system SHALL redirect the user to the Dropbox consent page

#### Scenario: Callback with code

- **WHEN** the user is redirected back to `GET /settings/storage/oauth/dropbox/callback?code=...`
- **THEN** the system SHALL exchange the code for tokens, store them in `StorageSetting.config_encrypted`, and redirect to `/settings/storage` with a success message

#### Scenario: Callback with error

- **WHEN** the user denies consent and is redirected back with `?error=access_denied`
- **THEN** the system SHALL redirect to `/settings/storage` with an error message

### Requirement: Automatic token refresh

The system SHALL automatically refresh expired OAuth access tokens before making API calls.

#### Scenario: Token expired

- **WHEN** a storage operation is attempted and the stored `access_token` has `expires_at` in the past
- **THEN** the system SHALL use the `refresh_token` to obtain a new `access_token`, update `StorageSetting`, and proceed with the operation

#### Scenario: Refresh token revoked

- **WHEN** the refresh token has been revoked by the user on the provider's side
- **THEN** the system SHALL raise an error indicating re-authorization is required and update the storage status to "error"
