## ADDED Requirements

### Requirement: Web UI requires password authentication
The web UI SHALL be protected by HTTP Basic Auth using a configurable password from the `WEB_PASSWORD` environment variable. A fixed username ("_") is used internally; users only need to enter the password when prompted by the browser.

#### Scenario: Unauthenticated access is rejected
- **WHEN** a browser request arrives at any web UI route (e.g., `/`, `/documents`) without Basic Auth credentials
- **THEN** the server SHALL respond with HTTP 401 and a `WWW-Authenticate: Basic` header

#### Scenario: Correct password grants access
- **WHEN** a browser sends a request with the correct password (any username)
- **THEN** the server SHALL process the request and return the appropriate page

#### Scenario: Incorrect password is rejected
- **WHEN** a browser sends a request with an incorrect password
- **THEN** the server SHALL respond with HTTP 401

#### Scenario: Credentials are remembered by browser
- **WHEN** a user authenticates successfully in a browser session
- **THEN** the browser SHALL cache credentials and not prompt again for subsequent requests in the same session

### Requirement: Telegram webhook bypasses Basic Auth
The Telegram webhook endpoint (`/api/telegram/webhook`) SHALL NOT require HTTP Basic Auth. It is protected separately by the Telegram secret token.

#### Scenario: Telegram POST reaches Rails without auth
- **WHEN** Telegram sends a POST to `/api/telegram/webhook` with the correct `X-Telegram-Bot-Api-Secret-Token`
- **THEN** the request SHALL be processed without Basic Auth challenge

#### Scenario: Webhook still validates Telegram secret
- **WHEN** a POST arrives at `/api/telegram/webhook` without the correct `X-Telegram-Bot-Api-Secret-Token`
- **THEN** the server SHALL respond with HTTP 403 (Forbidden), not 401

### Requirement: WEB_PASSWORD is configurable via environment
The password for web UI access SHALL be read from the `WEB_PASSWORD` environment variable. If `WEB_PASSWORD` is not set or empty, Rails SHALL raise a startup error (fail-fast; no fallback default).

#### Scenario: App starts with WEB_PASSWORD set
- **WHEN** `WEB_PASSWORD` environment variable is set to a non-empty string
- **THEN** the Rails application SHALL start and require that password for web UI access

#### Scenario: Missing WEB_PASSWORD causes startup error
- **WHEN** `WEB_PASSWORD` environment variable is absent or empty in production
- **THEN** the Rails application SHALL raise an error and refuse to start

### Requirement: nginx proxies web UI routes to Rails
The nginx server block on DO SHALL proxy all routes (except `/api/telegram/webhook`) to the Rails app at `http://10.8.0.5:3000`.

#### Scenario: Browser request reaches Rails
- **WHEN** a browser sends a GET request to `https://inbox.fedosov.me/`
- **THEN** nginx SHALL forward the request to `http://10.8.0.5:3000/` with correct proxy headers

#### Scenario: Non-webhook routes are proxied
- **WHEN** a browser navigates to `https://inbox.fedosov.me/documents`
- **THEN** nginx SHALL proxy the request to Rails, which serves the documents index page
